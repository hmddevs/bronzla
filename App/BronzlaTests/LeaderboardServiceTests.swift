import Foundation
import Testing
@testable import Bronzla

/// Exercises `LeaderboardServiceProviding` against `SampleLeaderboardProvider` only: there is
/// no live backend to reach from a unit test host, mirroring the UV service tests' use of
/// `SampleUVProvider` rather than the real WeatherKit provider.
@Suite("Leaderboard")
struct LeaderboardServiceTests {

    @Test("Sign in returns a session carrying the supplied display name")
    func signInReturnsDisplayName() async throws {
        let service = SampleLeaderboardProvider()
        let session = try await service.signIn(identityToken: "token", displayName: "Deniz")
        #expect(session.displayName == "Deniz")
    }

    @Test("Sign in falls back to a default display name when none is supplied")
    func signInFallsBackWhenNoDisplayName() async throws {
        let service = SampleLeaderboardProvider()
        let session = try await service.signIn(identityToken: "token", displayName: nil)
        #expect(!session.displayName.isEmpty)
    }

    @Test("Fetch leaderboard respects the requested limit")
    func fetchLeaderboardRespectsLimit() async throws {
        let service = SampleLeaderboardProvider()
        let entries = try await service.fetchLeaderboard(limit: 2)
        #expect(entries.count == 2)
    }

    @Test("An injected failure surfaces from every method")
    func injectedFailureSurfaces() async {
        let service = SampleLeaderboardProvider(failure: .unauthorized)

        await #expect(throws: LeaderboardError.unauthorized) {
            _ = try await service.signIn(identityToken: "token", displayName: nil)
        }
        await #expect(throws: LeaderboardError.unauthorized) {
            try await service.submitScore(.zero, displayName: "Deniz")
        }
        await #expect(throws: LeaderboardError.unauthorized) {
            _ = try await service.fetchLeaderboard(limit: 10)
        }
        await #expect(throws: LeaderboardError.unauthorized) {
            try await service.deleteAccount()
        }
    }

    @Test("currentSession reflects whatever was stored, without a network call")
    func currentSessionReflectsStoredValue() {
        let session = LeaderboardSession(sessionToken: "abc", displayName: "Ece")
        let signedIn = SampleLeaderboardProvider(storedSession: session)
        #expect(signedIn.currentSession() == session)

        let signedOut = SampleLeaderboardProvider()
        #expect(signedOut.currentSession() == nil)
    }

    @Test("Two entries with the same display name still get distinct identities")
    func entriesWithSameDisplayNameHaveDistinctIDs() {
        let first = LeaderboardEntry(displayName: "Deniz", score: 100)
        let second = LeaderboardEntry(displayName: "Deniz", score: 50)
        #expect(first.id != second.id)
    }

    @Test("A leaderboard entry decodes from server JSON that never includes an id")
    func entryDecodesWithoutServerSuppliedID() throws {
        let json = Data(#"{"displayName":"Deniz","score":210}"#.utf8)
        let entry = try JSONDecoder().decode(LeaderboardEntry.self, from: json)
        #expect(entry.displayName == "Deniz")
        #expect(entry.score == 210)
    }
}

/// Exercises the display-name validation used by the required sign-in confirmation step, in
/// isolation from the SwiftUI view that hosts it.
@Suite("Display name validation")
struct DisplayNameValidationTests {

    @Test("A non-empty, trimmed name is acceptable")
    func acceptsTrimmedName() {
        #expect(DisplayNameValidation.isAcceptable("Deniz"))
        #expect(DisplayNameValidation.isAcceptable("  Deniz  "))
    }

    @Test("An empty or whitespace-only name is rejected")
    func rejectsBlankName() {
        #expect(!DisplayNameValidation.isAcceptable(""))
        #expect(!DisplayNameValidation.isAcceptable("   "))
    }

    @Test("Trimming strips leading and trailing whitespace only")
    func trimsWhitespace() {
        #expect(DisplayNameValidation.trimmed("  Deniz Y  ") == "Deniz Y")
    }
}
