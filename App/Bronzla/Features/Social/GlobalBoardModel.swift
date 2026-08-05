import Foundation
import Observation

/// Orchestrates the global leaderboard tab: the signed-in session, the fetch, and its
/// failure state.
///
/// This screen gets a model because it coordinates async work (sign-in, fetch, account
/// deletion) and owns a failure state, matching `DashboardModel`'s reason for existing.
@MainActor
@Observable
final class GlobalBoardModel {

    enum Phase: Equatable {
        case idle
        case loading
        case loaded([LeaderboardEntry])
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var session: LeaderboardSession?

    private var inFlight: Task<Void, Never>?

    /// Restores whatever session is already on the Keychain, so a returning user is not asked
    /// to sign in again every launch.
    func restoreSession(using service: any LeaderboardServiceProviding) {
        session = service.currentSession()
    }

    func signedIn(_ session: LeaderboardSession, using service: any LeaderboardServiceProviding) {
        self.session = session
        load(using: service)
    }

    func load(using service: any LeaderboardServiceProviding, limit: Int = 50) {
        guard session != nil else { return }
        inFlight?.cancel()
        phase = .loading

        inFlight = Task { [weak self] in
            guard let self else { return }
            do {
                let entries = try await service.fetchLeaderboard(limit: limit)
                guard !Task.isCancelled else { return }
                self.phase = .loaded(entries)
            } catch {
                guard !Task.isCancelled else { return }
                let leaderboardError = error as? LeaderboardError
                self.phase = .failed(
                    leaderboardError?.errorDescription
                        ?? String(localized: "Could not load the leaderboard. Please try again.")
                )
            }
        }
    }

    func signOut(using service: any LeaderboardServiceProviding) {
        service.signOut()
        session = nil
        phase = .idle
    }
}
