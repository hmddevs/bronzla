import Foundation
import Testing
@testable import Bronzla

/// Timer arithmetic, driven by an injected clock so a forty-minute session takes microseconds
/// to test and pause behaviour is exercised deterministically.
@Suite("Timer state")
struct TimerStateTests {

    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)

    private func plan(minutes: Double = 30, spf: Int = 30, uv: Double = 8) -> TimerPlan {
        TimerPlan(totalDuration: .seconds(minutes * 60), skinType: .iii, spf: spf, uvIndexAtStart: uv)
    }

    private func state(minutes: Double = 30, spf: Int = 30) -> TimerState {
        TimerState(plan: plan(minutes: minutes, spf: spf), startedAt: t0)
    }

    // MARK: - Elapsed

    @Test("A fresh session starts running with nothing elapsed")
    func startsRunning() {
        let state = state()
        #expect(state.isRunning)
        #expect(state.elapsed(at: t0) == 0)
        #expect(state.progress(at: t0) == 0)
    }

    @Test("Elapsed time tracks the wall clock, not a tick count")
    func elapsedFollowsWallClock() {
        let state = state()
        #expect(state.elapsed(at: t0.addingTimeInterval(600)) == 600)
        // The crucial case: the app was suspended for the whole session and never ticked once.
        #expect(state.elapsed(at: t0.addingTimeInterval(1800)) == 1800)
    }

    @Test("Remaining time floors at zero and never goes negative")
    func remainingFloorsAtZero() {
        let state = state()
        #expect(state.remaining(at: t0.addingTimeInterval(1800)) == 0)
        #expect(state.remaining(at: t0.addingTimeInterval(999_999)) == 0)
    }

    @Test("Progress is capped at one however long the app was away")
    func progressIsCapped() {
        let state = state()
        #expect(state.progress(at: t0.addingTimeInterval(99_999)) == 1)
    }

    @Test("A backwards clock cannot wind the session backwards")
    func backwardsClockIsIgnored() {
        // Timezone change, manual clock edit or an NTP correction mid-session.
        let state = state()
        #expect(state.elapsed(at: t0.addingTimeInterval(-500)) == 0)
        #expect(state.remaining(at: t0.addingTimeInterval(-500)) == 1800)
    }

    // MARK: - Pause and resume

    @Test("Paused time does not count towards the session")
    func pauseBanksElapsedTime() {
        var state = state()
        state.pause(at: t0.addingTimeInterval(300))

        #expect(!state.isRunning)
        // Ten minutes of wall clock pass while paused; elapsed must not move.
        #expect(state.elapsed(at: t0.addingTimeInterval(900)) == 300)
    }

    @Test("Resuming continues from the banked total")
    func resumeContinuesFromBankedTotal() {
        var state = state()
        state.pause(at: t0.addingTimeInterval(300))
        state.resume(at: t0.addingTimeInterval(900))

        #expect(state.isRunning)
        #expect(state.elapsed(at: t0.addingTimeInterval(900)) == 300)
        #expect(state.elapsed(at: t0.addingTimeInterval(1200)) == 600)
    }

    @Test("Repeated pauses accumulate correctly across several stretches")
    func multiplePausesAccumulate() {
        var state = state()
        state.pause(at: t0.addingTimeInterval(120))
        state.resume(at: t0.addingTimeInterval(300))
        state.pause(at: t0.addingTimeInterval(480))
        state.resume(at: t0.addingTimeInterval(600))

        // Ran 0-120 and 300-480, so 300 seconds banked, then running again from 600.
        #expect(state.elapsed(at: t0.addingTimeInterval(700)) == 400)
    }

    @Test("Pausing twice or resuming twice is a no-op rather than corrupting the total")
    func redundantTransitionsAreIgnored() {
        var state = state()
        state.pause(at: t0.addingTimeInterval(300))
        state.pause(at: t0.addingTimeInterval(600))
        #expect(state.elapsed(at: t0.addingTimeInterval(900)) == 300)

        state.resume(at: t0.addingTimeInterval(900))
        state.resume(at: t0.addingTimeInterval(1200))
        #expect(state.elapsed(at: t0.addingTimeInterval(1200)) == 600)
    }

    // MARK: - Completion and flip

    @Test("A session finishes exactly at its planned duration")
    func finishesAtPlannedDuration() {
        let state = state()
        #expect(!state.isFinished(at: t0.addingTimeInterval(1799)))
        #expect(state.isFinished(at: t0.addingTimeInterval(1800)))
    }

    @Test("Pausing delays completion by the paused time")
    func pauseDelaysCompletion() {
        var state = state()
        state.pause(at: t0.addingTimeInterval(600))
        state.resume(at: t0.addingTimeInterval(1200))
        // 600 banked, so 1200 more running time is needed: finishes at t0 + 2400.
        #expect(!state.isFinished(at: t0.addingTimeInterval(2399)))
        #expect(state.isFinished(at: t0.addingTimeInterval(2400)))
    }

    @Test("The flip prompt appears at halfway and clears once acknowledged")
    func flipPromptLifecycle() {
        var state = state()
        #expect(!state.isAwaitingFlip(at: t0.addingTimeInterval(899)))
        #expect(state.isAwaitingFlip(at: t0.addingTimeInterval(900)))

        state.acknowledgeFlip()
        #expect(!state.isAwaitingFlip(at: t0.addingTimeInterval(1200)))
    }

    // MARK: - Alert scheduling

    @Test("Alerts are scheduled as absolute future dates")
    func alertDatesAreAbsoluteAndFuture() throws {
        let state = state(minutes: 30)
        let alerts = try #require(state.pendingAlertDates(at: t0))

        #expect(alerts.flip == t0.addingTimeInterval(900))
        #expect(alerts.end == t0.addingTimeInterval(1800))
        // Under two hours, so no reapply alert should be queued.
        #expect(alerts.reapply.isEmpty)
    }

    @Test("Alerts already in the past are dropped rather than fired immediately")
    func pastAlertsAreDropped() throws {
        var state = state(minutes: 30)
        state.acknowledgeFlip()
        let alerts = try #require(state.pendingAlertDates(at: t0.addingTimeInterval(1000)))

        #expect(alerts.flip == nil)
        #expect(alerts.end == t0.addingTimeInterval(1800))
    }

    @Test("A paused session schedules nothing")
    func pausedSessionSchedulesNothing() {
        var state = state()
        state.pause(at: t0.addingTimeInterval(300))
        #expect(state.pendingAlertDates(at: t0.addingTimeInterval(300)) == nil)
    }

    @Test("Alert dates shift by the paused duration after a resume")
    func alertDatesAccountForPauses() throws {
        var state = state(minutes: 30)
        state.pause(at: t0.addingTimeInterval(600))
        state.resume(at: t0.addingTimeInterval(1200))

        let alerts = try #require(state.pendingAlertDates(at: t0.addingTimeInterval(1200)))
        // 600 elapsed, so the halfway point is 300 seconds away, not 300 seconds ago.
        #expect(alerts.flip == t0.addingTimeInterval(1500))
        #expect(alerts.end == t0.addingTimeInterval(2400))
    }

    // MARK: - Round trip

    @Test("State survives an encode and decode, so a killed app resumes correctly")
    func stateRoundTripsThroughCoding() throws {
        var original = state()
        original.pause(at: t0.addingTimeInterval(420))
        original.acknowledgeFlip()

        let data = try JSONEncoder.bronzla.encode(original)
        let restored = try JSONDecoder.bronzla.decode(TimerState.self, from: data)

        #expect(restored == original)
        #expect(restored.elapsed(at: t0.addingTimeInterval(5000)) == 420)
    }
}

@Suite("Timer plan")
struct TimerPlanTests {

    @Test("The recommended plan never exceeds the safe session length")
    func recommendedPlanMatchesCalculator() throws {
        let plan = try #require(TimerPlan.recommended(uvIndex: 8, skinType: .iii, spf: 30))
        let expected = try #require(ExposureCalculator.recommendedSession(uvIndex: 8, skinType: .iii, spf: 30))
        #expect(plan.totalDuration == expected)
    }

    @Test("No plan exists without UV")
    func noPlanWithoutUV() {
        #expect(TimerPlan.recommended(uvIndex: 0, skinType: .iii, spf: 30) == nil)
    }

    @Test("The flip point is the midpoint")
    func flipIsMidpoint() {
        let plan = TimerPlan(totalDuration: .seconds(1800), skinType: .iii, spf: 30, uvIndexAtStart: 8)
        #expect(plan.flipAt == .seconds(900))
    }

    @Test("Short sessions queue no reapply alert")
    func shortSessionsHaveNoReapply() {
        let plan = TimerPlan(totalDuration: .seconds(1800), skinType: .iii, spf: 30, uvIndexAtStart: 8)
        #expect(plan.reapplyPoints.isEmpty)
    }

    @Test("Long sessions queue a reapply alert every two hours")
    func longSessionsReapplyEveryTwoHours() {
        let plan = TimerPlan(totalDuration: .seconds(5 * 3600), skinType: .vi, spf: 30, uvIndexAtStart: 3)
        #expect(plan.reapplyPoints == [.seconds(7200), .seconds(14400)])
    }

    @Test("Bare skin gets no reapply alerts, since there is nothing to reapply")
    func bareSkinHasNoReapply() {
        let plan = TimerPlan(totalDuration: .seconds(5 * 3600), skinType: .vi, spf: 1, uvIndexAtStart: 3)
        #expect(plan.reapplyPoints.isEmpty)
    }

    @Test("A user may shorten a session")
    func userCanShortenSession() throws {
        let plan = try #require(TimerPlan.recommended(uvIndex: 8, skinType: .iii, spf: 30))
        let shorter = plan.adjusted(to: .seconds(600))
        #expect(shorter.totalDuration == .seconds(600))
    }

    @Test("A user may not extend a session beyond the safe ceiling")
    func userCannotExceedSafeCeiling() throws {
        let plan = try #require(TimerPlan.recommended(uvIndex: 8, skinType: .iii, spf: 30))
        let attempted = plan.adjusted(to: .seconds(99_999))
        #expect(attempted.totalDuration == plan.totalDuration)
    }

    @Test("A session cannot be shortened below one minute")
    func sessionHasMinimumLength() throws {
        let plan = try #require(TimerPlan.recommended(uvIndex: 8, skinType: .iii, spf: 30))
        #expect(plan.adjusted(to: .seconds(0)).totalDuration == .seconds(60))
        #expect(plan.adjusted(to: .seconds(-500)).totalDuration == .seconds(60))
    }
}

@Suite("Timer formatting")
struct TimerFormattingTests {

    @Test(
        "Clock rounds up so the ring never reads zero while running",
        arguments: [
            (0.0, "00:00"), (0.4, "00:01"), (59.0, "00:59"),
            (60.0, "01:00"), (1_500.0, "25:00"), (3_600.0, "1:00:00"),
            (3_661.0, "1:01:01"),
        ]
    )
    func clockFormatting(interval: TimeInterval, expected: String) {
        #expect(TimerRing.clock(interval) == expected)
    }

    @Test("Negative intervals format as zero rather than a minus sign")
    func negativeIntervalsAreSafe() {
        #expect(TimerRing.clock(-90) == "00:00")
    }
}
