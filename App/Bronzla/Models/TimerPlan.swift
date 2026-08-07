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
    ///
    /// This is the pre-session preview only, shown in the setup breakdown before anything has
    /// happened. Once a session is running the live schedule is `TimerState.reapplyOffsets`,
    /// which rebases on the moment the user last left the water. Do not schedule from here.
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
    /// Elapsed running time from which the two-hour reapply clock is measured. Zero for a
    /// session in which the user has never reported leaving the water.
    private(set) var reapplyBaseline: TimeInterval
    /// True between reporting a water exit and confirming the sunscreen has gone back on.
    private(set) var awaitingReapply: Bool

    init(plan: TimerPlan, startedAt: Date) {
        self.plan = plan
        self.startedAt = startedAt
        self.accumulated = 0
        self.resumedAt = startedAt
        self.completedFlip = false
        self.reapplyBaseline = 0
        self.awaitingReapply = false
    }

    /// Spelled out rather than synthesised, because `init(from:)` below is hand-written and the
    /// key set is part of the on-disk format that older builds already wrote.
    private enum CodingKeys: String, CodingKey {
        case plan, startedAt, accumulated, resumedAt, completedFlip, reapplyBaseline, awaitingReapply
    }

    /// Decoded by hand so a session persisted by an older build, whose JSON carries neither of
    /// the two water-exit keys, restores with the defaults instead of throwing and stranding a
    /// running timer. Encoding stays synthesised.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        plan = try container.decode(TimerPlan.self, forKey: .plan)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        accumulated = try container.decode(TimeInterval.self, forKey: .accumulated)
        resumedAt = try container.decodeIfPresent(Date.self, forKey: .resumedAt)
        completedFlip = try container.decode(Bool.self, forKey: .completedFlip)
        reapplyBaseline = try container.decodeIfPresent(TimeInterval.self, forKey: .reapplyBaseline) ?? 0
        awaitingReapply = try container.decodeIfPresent(Bool.self, forKey: .awaitingReapply) ?? false
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

    /// Records that the user has just come out of the water, or towelled off.
    ///
    /// Water contact and towelling remove sunscreen well before the two-hour mark, so the
    /// reapply clock restarts from this moment rather than from the start of the session.
    /// Measured in elapsed running time, so a pause cannot drift the baseline.
    mutating func acknowledgeWaterExit(at now: Date) {
        reapplyBaseline = elapsed(at: now)
        awaitingReapply = true
    }

    /// Clears the reapply prompt. Deliberately leaves the baseline where the water exit put it:
    /// the two hours run from leaving the water, not from the moment the cream went back on,
    /// which is the conservative direction and costs the user nothing but an early reminder.
    mutating func acknowledgeReapply() {
        awaitingReapply = false
    }

    /// The live reapply schedule, as offsets in elapsed running time.
    ///
    /// Unlike `TimerPlan.reapplyPoints` this rebases on the last reported water exit, so it is
    /// the schedule notifications are built from once a session is under way.
    var reapplyOffsets: [Duration] {
        guard plan.spf > 1 else { return [] }
        let interval = ExposureCalculator.reapplyInterval.seconds
        let total = plan.totalDuration.seconds
        let first = reapplyBaseline + interval
        guard interval > 0, total > first else { return [] }

        return stride(from: first, to: total, by: interval).map { .seconds($0) }
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
            reapply: reapplyOffsets.compactMap { date(forOffset: $0.seconds) },
            end: date(forOffset: plan.totalDuration.seconds) ?? now
        )
    }
}
