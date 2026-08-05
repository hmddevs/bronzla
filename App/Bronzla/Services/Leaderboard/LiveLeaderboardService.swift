import Foundation

/// Live implementation of `LeaderboardServiceProviding`, talking to the Bronzla backend over
/// plain `URLSession` and `Codable`. The first custom HTTP client in the app: kept a thin
/// single file rather than reaching for a networking library for four endpoints.
///
/// `baseURL` is injected so this can be pointed at a different deployment without touching
/// call sites. Defaults to the `infra/` CDK stack's dev stage (`BronzlaBackendStack-dev`);
/// repoint this once a production stage exists.
struct LiveLeaderboardService: LeaderboardServiceProviding {
    static let devBaseURL = URL(string: "https://mcl6x7izu6.execute-api.eu-central-1.amazonaws.com")!

    private let baseURL: URL
    private let session: URLSession
    private let store: KeychainSessionStore

    init(baseURL: URL = LiveLeaderboardService.devBaseURL, session: URLSession = .shared, store: KeychainSessionStore = KeychainSessionStore()) {
        self.baseURL = baseURL
        self.session = session
        self.store = store
    }

    func currentSession() -> LeaderboardSession? {
        store.load()
    }

    func signIn(identityToken: String, displayName: String?) async throws -> LeaderboardSession {
        struct RequestBody: Encodable {
            let identityToken: String
            let displayName: String?
        }
        struct ResponseBody: Decodable {
            let sessionToken: String
            let displayName: String
        }

        var request = URLRequest(url: baseURL.appending(path: "auth/apple"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(identityToken: identityToken, displayName: displayName))

        let response = try await send(request, as: ResponseBody.self)
        let newSession = LeaderboardSession(sessionToken: response.sessionToken, displayName: response.displayName)
        store.save(newSession)
        return newSession
    }

    func submitScore(_ score: BronzScore, displayName: String) async throws {
        struct RequestBody: Encodable {
            let displayName: String
            let score: Double
        }
        guard let currentSession = store.load() else { throw LeaderboardError.unauthorized }

        var request = URLRequest(url: baseURL.appending(path: "score"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentSession.sessionToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RequestBody(displayName: displayName, score: Double(score.total)))

        try await sendExpectingNoBody(request)
    }

    func fetchLeaderboard(limit: Int) async throws -> [LeaderboardEntry] {
        guard let currentSession = store.load() else { throw LeaderboardError.unauthorized }

        var components = URLComponents(url: baseURL.appending(path: "leaderboard"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components?.url else { throw LeaderboardError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(currentSession.sessionToken)", forHTTPHeaderField: "Authorization")

        return try await send(request, as: [LeaderboardEntry].self)
    }

    func deleteAccount() async throws {
        guard let currentSession = store.load() else { throw LeaderboardError.unauthorized }

        var request = URLRequest(url: baseURL.appending(path: "account"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(currentSession.sessionToken)", forHTTPHeaderField: "Authorization")

        try await sendExpectingNoBody(request)
        store.clear()
    }

    func signOut() {
        store.clear()
    }

    // MARK: - Transport

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw LeaderboardError.invalidResponse }

        if http.statusCode == 401 { throw LeaderboardError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw LeaderboardError.network("Unexpected status \(http.statusCode)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LeaderboardError.invalidResponse
        }
    }

    private func sendExpectingNoBody(_ request: URLRequest) async throws {
        let (_, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw LeaderboardError.invalidResponse }

        if http.statusCode == 401 { throw LeaderboardError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw LeaderboardError.network("Unexpected status \(http.statusCode)")
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw LeaderboardError.network(error.localizedDescription)
        }
    }
}
