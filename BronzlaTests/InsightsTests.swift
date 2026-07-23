import Foundation
import Testing
@testable import Bronzla

/// `InsightsSummary` is pure and dependency-free, so it is tested directly against
/// hand-built `TanSession` instances rather than through a `ModelContainer`.
@Suite("Insights summary")
struct InsightsSummaryTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    private func session(
        daysAgo: Int,
        durationMinutes: Double = 30,
        dose: Double = 0,
        skinType: SkinType = .iii,
        referenceDate: Date
    ) -> TanSession {
        let start = Self.calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        return TanSession(
            startedAt: start,
            endedAt: start.addingTimeInterval(durationMinutes * 60),
            placeName: "Test",
            spf: 30,
            skinType: skinType,
            erythemalDose: dose,
            peakUVIndex: 8
        )
    }

    // MARK: - Empty input

    @Test("Empty session list produces the zero-valued summary")
    func emptyInputProducesEmptySummary() {
        let summary = InsightsSummary.make(from: [], profile: nil)
        #expect(summary == .empty)
        #expect(summary.sessionCount == 0)
        #expect(summary.currentStreakDays == 0)
        #expect(summary.longestStreakDays == 0)
        #expect(summary.totalEstimatedVitaminD == 0)
        #expect(summary.weeklyMinutes.isEmpty)
    }

    // MARK: - Single session

    @Test("A single session today counts as a one-day streak and feeds this month's total")
    func singleSessionToday() {
        let now = Date.now
        let one = session(daysAgo: 0, durationMinutes: 45, dose: 100, referenceDate: now)

        let summary = InsightsSummary.make(from: [one], profile: nil, referenceDate: now, calendar: Self.calendar)

        #expect(summary.sessionCount == 1)
        #expect(summary.currentStreakDays == 1)
        #expect(summary.longestStreakDays == 1)
        #expect(summary.totalTimeAllTime == .seconds(45 * 60))
        #expect(summary.totalTimeThisMonth == .seconds(45 * 60))
    }

    @Test("A single session from last month does not count towards this month's total")
    func singleSessionLastMonth() {
        let now = Date.now
        let lastMonth = Self.calendar.date(byAdding: .month, value: -1, to: now)!
        let one = TanSession(
            startedAt: lastMonth,
            endedAt: lastMonth.addingTimeInterval(1800),
            placeName: "Test",
            spf: 30,
            skinType: .iii,
            erythemalDose: 50,
            peakUVIndex: 6
        )

        let summary = InsightsSummary.make(from: [one], profile: nil, referenceDate: now, calendar: Self.calendar)

        #expect(summary.totalTimeThisMonth == .zero)
        #expect(summary.totalTimeAllTime == .seconds(1800))
    }

    // MARK: - Streaks

    @Test("Three consecutive days ending today form a current streak of three")
    func consecutiveDaysFormCurrentStreak() {
        let now = Date.now
        let sessions = [
            session(daysAgo: 0, referenceDate: now),
            session(daysAgo: 1, referenceDate: now),
            session(daysAgo: 2, referenceDate: now),
        ]

        let summary = InsightsSummary.make(from: sessions, profile: nil, referenceDate: now, calendar: Self.calendar)

        #expect(summary.currentStreakDays == 3)
        #expect(summary.longestStreakDays == 3)
    }

    @Test("A gap breaks the current streak but the earlier run still counts as the longest")
    func gapBreaksCurrentStreakButNotLongest() {
        let now = Date.now
        let sessions = [
            // A five-day run, six to ten days ago.
            session(daysAgo: 6, referenceDate: now),
            session(daysAgo: 7, referenceDate: now),
            session(daysAgo: 8, referenceDate: now),
            session(daysAgo: 9, referenceDate: now),
            session(daysAgo: 10, referenceDate: now),
            // A single, unrelated session today.
            session(daysAgo: 0, referenceDate: now),
        ]

        let summary = InsightsSummary.make(from: sessions, profile: nil, referenceDate: now, calendar: Self.calendar)

        #expect(summary.currentStreakDays == 1)
        #expect(summary.longestStreakDays == 5)
    }

    @Test("Activity that stopped more than a day ago is not an ongoing streak")
    func staleActivityHasNoCurrentStreak() {
        let now = Date.now
        let sessions = [
            session(daysAgo: 5, referenceDate: now),
            session(daysAgo: 6, referenceDate: now),
        ]

        let summary = InsightsSummary.make(from: sessions, profile: nil, referenceDate: now, calendar: Self.calendar)

        #expect(summary.currentStreakDays == 0)
        #expect(summary.longestStreakDays == 2)
    }

    @Test("A session yesterday still counts as an ongoing streak today")
    func yesterdayStillCountsAsCurrent() {
        let now = Date.now
        let sessions = [session(daysAgo: 1, referenceDate: now)]

        let summary = InsightsSummary.make(from: sessions, profile: nil, referenceDate: now, calendar: Self.calendar)

        #expect(summary.currentStreakDays == 1)
    }

    // MARK: - Vitamin D

    @Test("Vitamin D estimate sums across sessions using the profile's exposed body fraction")
    func vitaminDSumsAcrossSessions() {
        let now = Date.now
        let skinType = SkinType.iii
        let profile = UserProfile(skinType: skinType, exposedBodyFraction: 0.6)

        // Two sessions, each at a known dose, so the expected sum can be computed independently.
        let doseOne = 100.0
        let doseTwo = 200.0
        let sessions = [
            session(daysAgo: 0, dose: doseOne, skinType: skinType, referenceDate: now),
            session(daysAgo: 1, dose: doseTwo, skinType: skinType, referenceDate: now),
        ]

        let expected =
            ExposureCalculator.estimatedVitaminD(dose: doseOne, skinType: skinType, exposedBodyFraction: 0.6) +
            ExposureCalculator.estimatedVitaminD(dose: doseTwo, skinType: skinType, exposedBodyFraction: 0.6)

        let summary = InsightsSummary.make(from: sessions, profile: profile, referenceDate: now, calendar: Self.calendar)

        #expect(abs(summary.totalEstimatedVitaminD - expected) < 0.001)
    }

    @Test("A missing profile falls back to a sensible default exposed body fraction")
    func missingProfileUsesDefaultExposure() {
        let now = Date.now
        let skinType = SkinType.iii
        let sessions = [session(daysAgo: 0, dose: 150, skinType: skinType, referenceDate: now)]

        let expected = ExposureCalculator.estimatedVitaminD(dose: 150, skinType: skinType, exposedBodyFraction: 0.6)
        let summary = InsightsSummary.make(from: sessions, profile: nil, referenceDate: now, calendar: Self.calendar)

        #expect(abs(summary.totalEstimatedVitaminD - expected) < 0.001)
    }

    // MARK: - Burn risk

    @Test("Sessions above one MED are counted as high burn risk")
    func highBurnRiskSessionsAreCounted() {
        let now = Date.now
        let skinType = SkinType.iii // MED 300
        let sessions = [
            session(daysAgo: 0, dose: 400, skinType: skinType, referenceDate: now), // risk > 1
            session(daysAgo: 1, dose: 100, skinType: skinType, referenceDate: now), // risk < 1
        ]

        let summary = InsightsSummary.make(from: sessions, profile: nil, referenceDate: now, calendar: Self.calendar)

        #expect(summary.highBurnRiskSessionCount == 1)
    }

    // MARK: - Weekly minutes

    @Test("Weekly minutes covers exactly eight weeks, oldest first, ending in the current week")
    func weeklyMinutesCoversEightWeeks() {
        let now = Date.now
        let summary = InsightsSummary.make(
            from: [session(daysAgo: 0, referenceDate: now)],
            profile: nil,
            referenceDate: now,
            calendar: Self.calendar
        )

        #expect(summary.weeklyMinutes.count == 8)
        #expect(summary.weeklyMinutes.last?.minutes == 30)
        #expect(summary.weeklyMinutes.dropLast().allSatisfy { $0.minutes == 0 })
    }
}
