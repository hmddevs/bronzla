import ActivityKit
import Foundation
import OSLog

/// Starts, updates and ends the session Live Activity.
///
/// Every call is a no-op when Live Activities are unavailable or the user has switched them
/// off, so the timer works exactly the same without one. A lock screen widget is a convenience
/// on top of the session, never a dependency of it.
@MainActor
struct LiveActivityController {

    private static let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "LiveActivity")

    private static var current: Activity<TanSessionAttributes>? {
        Activity<TanSessionAttributes>.activities.first
    }

    static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(state: TimerState, placeName: String, now: Date = .now) {
        guard isAvailable, current == nil else { return }

        let attributes = TanSessionAttributes(
            placeName: placeName,
            uvIndexAtStart: state.plan.uvIndexAtStart,
            skinTypeNumeral: state.plan.skinType.numeral,
            spf: state.plan.spf,
            startedAt: state.startedAt
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content(for: state, now: now),
                pushType: nil
            )
        } catch {
            logger.notice("Live Activity refused: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func update(state: TimerState, now: Date = .now) {
        guard let current else { return }
        Task { await current.update(content(for: state, now: now)) }
    }

    static func end() {
        guard let current else { return }
        // Dismiss immediately rather than leaving a finished timer on the lock screen, which
        // reads as a stuck app.
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - Private

    private static func content(for state: TimerState, now: Date) -> ActivityContent<TanSessionAttributes.ContentState> {
        let remaining = state.remaining(at: now)
        let elapsed = state.elapsed(at: now)
        let flipOffset = state.plan.flipAt.seconds - elapsed

        let contentState = TanSessionAttributes.ContentState(
            endsAt: now.addingTimeInterval(remaining),
            flipAt: flipOffset > 0 ? now.addingTimeInterval(flipOffset) : nil,
            isPaused: !state.isRunning,
            pausedElapsed: elapsed
        )

        // Staleness tells the system when the shown figure stops being trustworthy, so it can
        // dim the activity rather than display a confidently wrong countdown.
        return ActivityContent(
            state: contentState,
            staleDate: now.addingTimeInterval(max(remaining, 60))
        )
    }
}
