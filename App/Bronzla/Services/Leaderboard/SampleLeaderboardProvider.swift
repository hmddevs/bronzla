import Foundation

/// Deterministic stand-in for `LiveLeaderboardService`, used by SwiftUI previews and unit
/// tests where there is no backend to reach.
///
/// Mirrors `SampleUVProvider`'s shape: fixed sample content plus an injectable `failure` so
/// error states can be designed without unplugging anything.
struct SampleLeaderboardProvider: LeaderboardServiceProviding {
    /// Set to have every call throw, so error states can be exercised deterministically.
    var failure: LeaderboardError?
    /// Session to report as already signed in, or `nil` to start signed out.
    var storedSession: LeaderboardSession?
    var entries: [LeaderboardEntry] = [
        LeaderboardEntry(displayName: "Deniz", score: 210),
        LeaderboardEntry(displayName: "Ece", score: 180),
        LeaderboardEntry(displayName: "Kaan", score: 145)
    ]

    func currentSession() -> LeaderboardSession? {
        storedSession
    }

    func signIn(identityToken: String, displayName: String?) async throws -> LeaderboardSession {
        if let failure { throw failure }
        return LeaderboardSession(sessionToken: "sample-token", displayName: displayName ?? "Bronzla user")
    }

    func submitScore(_ score: BronzScore, displayName: String) async throws {
        if let failure { throw failure }
    }

    func fetchLeaderboard(limit: Int) async throws -> [LeaderboardEntry] {
        if let failure { throw failure }
        return Array(entries.prefix(limit))
    }

    func deleteAccount() async throws {
        if let failure { throw failure }
    }

    func signOut() {}
}
