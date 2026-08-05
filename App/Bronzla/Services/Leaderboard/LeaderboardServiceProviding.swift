import Foundation

/// Anything that can authenticate a person with Apple, hold their global leaderboard entry,
/// and remove it again.
///
/// The abstraction exists for the same reason as `UVDataProviding`: the live implementation
/// needs a network round trip to a server that does not exist in previews, unit tests, or an
/// unsigned simulator build, so callers are written against the protocol and never against
/// `URLSession` directly.
protocol LeaderboardServiceProviding: Sendable {
    /// Exchanges an Apple identity token for a Bronzla session. `displayName` is only sent on
    /// first sign-in, prefilled from Apple's one-time name grant and editable by the person
    /// before it is sent; the server never receives a real name or email.
    func signIn(identityToken: String, displayName: String?) async throws -> LeaderboardSession

    /// Pushes the current total to the global leaderboard, overwriting any previous entry for
    /// this account. Requires a stored session; call `signIn` first.
    func submitScore(_ score: BronzScore, displayName: String) async throws

    /// Top entries for the global leaderboard, ordered highest score first.
    func fetchLeaderboard(limit: Int) async throws -> [LeaderboardEntry]

    /// Permanently deletes the account, its stored session, and its leaderboard entry
    /// server-side. This is the mandatory Apple Guideline 5.1.1(v) account-deletion path.
    func deleteAccount() async throws

    /// Clears the locally stored session without contacting the server. Used for local
    /// sign-out, distinct from `deleteAccount()` which also erases server-side data.
    func signOut()

    /// The session restored from local storage on launch, or `nil` if nobody is signed in.
    func currentSession() -> LeaderboardSession?
}

/// A signed-in session: the opaque token the server issued, plus the display name it holds.
struct LeaderboardSession: Equatable, Sendable, Codable {
    let sessionToken: String
    let displayName: String
}

/// One row of the global leaderboard. Never carries an identifier tying it back to an Apple
/// account; the server itself never returns one.
///
/// `id` is a client-side identifier only, generated fresh on decode. It exists purely so
/// SwiftUI can tell rows apart when two people pick the same display name; it is never sent to
/// or read from the server, and it is not stable across separate fetches of the same entry.
struct LeaderboardEntry: Equatable, Sendable, Codable, Identifiable {
    let id: UUID = UUID()
    let displayName: String
    let score: Double

    private enum CodingKeys: String, CodingKey {
        case displayName, score
    }

    init(displayName: String, score: Double) {
        self.displayName = displayName
        self.score = score
    }
}

enum LeaderboardError: LocalizedError, Equatable {
    case network(String)
    case unauthorized
    case invalidResponse

    /// The underlying failure, for the same diagnostic reason as `UVDataError.diagnosticDetail`:
    /// plain language stays in `errorDescription`, and this is never written to the unified log.
    var diagnosticDetail: String? {
        if case .network(let detail) = self { return detail }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .network:
            String(localized: "Could not reach the leaderboard. It may be your connection, or the service may be briefly unavailable.")
        case .unauthorized:
            String(localized: "Your session has expired. Please sign in again.")
        case .invalidResponse:
            String(localized: "The leaderboard sent back something Bronzla could not understand.")
        }
    }
}
