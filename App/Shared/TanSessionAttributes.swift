import ActivityKit
import Foundation

/// The contract between the app and its Live Activity.
///
/// Compiled into both targets, so it is deliberately self-contained: no `TimerState`, no
/// `TimerPlan`, no `ExposureCalculator`. Widening this file drags the whole domain into the
/// widget extension, which then has to be kept in step with it forever.
///
/// The state carries absolute dates rather than a remaining duration, because a Live Activity
/// is redrawn by the system on its own schedule. `Text(timerInterval:)` counts down from a
/// date range without the app running at all; a stored "seconds remaining" would freeze the
/// moment the app was suspended, which is precisely when the lock screen matters most.
struct TanSessionAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        /// When the session ends. Drives the countdown.
        var endsAt: Date
        /// When the user should turn over, or `nil` once acknowledged or passed.
        var flipAt: Date?
        var isPaused: Bool
        /// Elapsed seconds banked at the moment of pausing, so a paused activity can show a
        /// static figure instead of a countdown that keeps running.
        var pausedElapsed: TimeInterval

        var isAwaitingFlip: Bool {
            guard let flipAt else { return false }
            return flipAt <= .now
        }
    }

    /// Fixed for the lifetime of the activity.
    let placeName: String
    let uvIndexAtStart: Double
    let skinTypeNumeral: String
    let spf: Int
    let startedAt: Date
}
