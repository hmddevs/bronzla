import Foundation

/// What a session will look like before it starts: how long, when to turn over, when to
/// reapply. Derived once from the UV reading and the user's skin, then frozen.
///
/// Frozen deliberately. If the plan tracked live UV, a passing cloud would extend someone's
/// session mid-lie-down and the timer would become untrustworthy. The dose actually received
/// is measured separately against the real UV profile.
struct TimerPlan: Codable, Equatable, Sendable {
    let totalDuration: Duration
    let skinType: SkinType
    let spf: Int
    /// UV index at the moment the plan was made, kept for the session record.
    let uvIndexAtStart: Double

    /// Halfway. People remember "halfway"; they do not remember "at 17 minutes".
    var flipAt: Duration { ExposureCalculator.flipInterval(for: totalDuration) }

    /// Offsets at which to reapply sunscreen. Empty when the session is shorter than the
    /// two-hour interval, because an alert that fires after the timer ends is noise.
    var reapplyPoints: [Duration] {
        guard spf > 1 else { return [] }
        let interval = ExposureCalculator.reapplyInterval.seconds
        let total = totalDuration.seconds
        guard interval > 0, total > interval else { return [] }

        return stride(from: interval, to: total, by: interval).map { .seconds($0) }
    }

    /// Builds the recommended plan, or `nil` when there is no UV worth tanning in.
    static func recommended(uvIndex: Double, skinType: SkinType, spf: Int) -> TimerPlan? {
        guard let session = ExposureCalculator.recommendedSession(uvIndex: uvIndex, skinType: skinType, spf: spf) else {
            return nil
        }
        return TimerPlan(totalDuration: session, skinType: skinType, spf: spf, uvIndexAtStart: uvIndex)
    }

    /// A plan of a user-chosen length. Clamped to the safety ceiling: the user may shorten a
    /// session freely, but the app will not help them exceed what their skin can take.
    func adjusted(to duration: Duration) -> TimerPlan {
        let ceiling = ExposureCalculator.recommendedSession(
            uvIndex: uvIndexAtStart,
            skinType: skinType,
            spf: spf
        ) ?? ExposureCalculator.maximumRecommendedSession

        let floor = Duration.seconds(60)
        let clamped = min(max(duration.seconds, floor.seconds), ceiling.seconds)
        return TimerPlan(
            totalDuration: .seconds(clamped),
            skinType: skinType,
            spf: spf,
            uvIndexAtStart: uvIndexAtStart
        )
    }
}

/// The running state of a session.
///
/// Pure value type with every time-dependent function taking an explicit `now`. There is no
/// hidden clock, no stored countdown and no tick accumulator, so the arithmetic is testable
/// without waiting real seconds, and a suspended app resumes with the correct elapsed time
/// rather than a frozen one.
struct TimerState: Codable, Equatable, Sendable {
    let plan: TimerPlan
    let startedAt: Date
    /// Time banked from previous running stretches.
    private(set) var accumulated: TimeInterval
    /// When the current running stretch began. `nil` means paused.
    private(set) var resumedAt: Date?
    private(set) var completedFlip: Bool

    init(plan: TimerPlan, startedAt: Date) {
        self.plan = plan
        self.startedAt = startedAt
        self.accumulated = 0
        self.resumedAt = startedAt
        self.completedFlip = false
    }

    var isRunning: Bool { resumedAt != nil }

    /// Elapsed running time, excluding any paused stretches.
    func elapsed(at now: Date) -> TimeInterval {
        guard let resumedAt else { return accumulated }
        // A backwards clock (timezone change, manual adjustment, NTP correction) must never
        // produce negative elapsed time and wind the session backwards.
        return accumulated + max(0, now.timeIntervalSince(resumedAt))
    }

    func remaining(at now: Date) -> TimeInterval {
        max(0, plan.totalDuration.seconds - elapsed(at: now))
    }

    func progress(at now: Date) -> Double {
        let total = plan.totalDuration.seconds
        guard total > 0 else { return 1 }
        return min(1, elapsed(at: now) / total)
    }

    func isFinished(at now: Date) -> Bool {
        elapsed(at: now) >= plan.totalDuration.seconds
    }

    /// True once the halfway point has passed and the user has not acknowledged the flip.
    func isAwaitingFlip(at now: Date) -> Bool {
        !completedFlip && elapsed(at: now) >= plan.flipAt.seconds
    }

    mutating func pause(at now: Date) {
        guard let resumedAt else { return }
        accumulated += max(0, now.timeIntervalSince(resumedAt))
        self.resumedAt = nil
    }

    mutating func resume(at now: Date) {
        guard resumedAt == nil else { return }
        resumedAt = now
    }

    mutating func acknowledgeFlip() {
        completedFlip = true
    }

    /// Absolute wall-clock dates at which each alert should fire, given the current state.
    /// Used to schedule notifications, so they must be real dates rather than offsets.
    func pendingAlertDates(at now: Date) -> (flip: Date?, reapply: [Date], end: Date)? {
        guard isRunning else { return nil }
        let elapsedNow = elapsed(at: now)

        func date(forOffset offset: TimeInterval) -> Date? {
            let delta = offset - elapsedNow
            return delta > 0 ? now.addingTimeInterval(delta) : nil
        }

        return (
            flip: completedFlip ? nil : date(forOffset: plan.flipAt.seconds),
            reapply: plan.reapplyPoints.compactMap { date(forOffset: $0.seconds) },
            end: date(forOffset: plan.totalDuration.seconds) ?? now
        )
    }
}
