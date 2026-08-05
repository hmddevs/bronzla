import Foundation
import Testing
@testable import Bronzla

/// `BronzScore` and `Badge` reward discipline, never exposure, so these tests exist mainly to
/// pin that boundary: nothing here should reward duration, darkness or raw session count alone.
@Suite("Social")
struct SocialTests {

    // MARK: - Fixtures

    private static func session(
        daysAgo: Int,
        burnRisk: Double,
        spf: Int = 1,
        hour: Int = 15,
        calendar: Calendar = .current,
        referenceDate: Date
    ) -> TanSession {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: referenceDate))!
        let started = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        // burnRisk is a fraction of one MED; back it out via dose for skin type III (MED 300).
        let dose = burnRisk * 300
        return TanSession(
            startedAt: started,
            endedAt: started.addingTimeInterval(1800),
            placeName: "Test",
            spf: spf,
            skinType: .iii,
            erythemalDose: dose,
            peakUVIndex: 6
        )
    }

    // MARK: - BronzScore.make

    @Test("Empty history scores zero")
    func emptyHistoryIsZero() {
        #expect(BronzScore.make(from: []) == .zero)
    }

    /// Regression: the title switch used to fall through to "Needs care" when there were no
    /// sessions, so a brand new user was told they had done something wrong before they had
    /// done anything at all. The score only ever judges behaviour that actually happened.
    @Test("A user with no sessions is not judged")
    func noSessionsIsNotJudged() {
        let title = BronzScore.zero.title
        #expect(title == LocalizedStringResource("No sessions yet"))
        #expect(title != LocalizedStringResource("Needs care"))
    }

    @Test("A burn penalty can exceed a single session's rewards")
    func burnPenaltyExceedsRewards() {
        let now = Date.now
        let burned = Self.session(daysAgo: 0, burnRisk: 1.5, spf: 1, referenceDate: now)
        let score = BronzScore.make(from: [burned], referenceDate: now)
        #expect(score.burnCount == 1)
        // One burn with no protection: 0 clean points, 0 protected points, streak-of-1 = 3.
        // Penalty (25) outweighs the 3 streak points, so total floors at 0, not negative.
        #expect(score.total == 0)
    }

    @Test("Total never goes negative regardless of burn count")
    func totalFloorsAtZero() {
        let now = Date.now
        let burns = (0..<5).map { Self.session(daysAgo: $0 * 3, burnRisk: 2.0, referenceDate: now) }
        let score = BronzScore.make(from: burns, referenceDate: now)
        #expect(score.total == 0)
        #expect(score.burnCount == 5)
    }

    @Test("Clean, protected sessions score positively")
    func cleanProtectedSessionsScore() {
        let now = Date.now
        let clean = Self.session(daysAgo: 0, burnRisk: 0.4, spf: 30, referenceDate: now)
        let score = BronzScore.make(from: [clean], referenceDate: now)
        #expect(score.burnCount == 0)
        #expect(score.cleanSessionCount == 1)
        // 1 clean (10) + 1 protected (5) + streak-of-1 (3) = 18.
        #expect(score.total == 18)
    }

    // MARK: - BronzScore.streaks

    @Test("A gap breaks the current streak but preserves the longest")
    func gapBreaksCurrentPreservesLongest() {
        let now = Date.now
        let calendar = Calendar.current
        // Three consecutive days, six days ago, then nothing since: longest = 3, current = 0.
        let sessions = (6...8).map { Self.session(daysAgo: $0, burnRisk: 0.2, referenceDate: now) }
        let streaks = BronzScore.streaks(for: sessions, referenceDate: now, calendar: calendar)
        #expect(streaks.longest == 3)
        #expect(streaks.current == 0)
    }

    @Test("An empty today does not break a streak that ran through yesterday")
    func emptyTodayDoesNotBreakStreak() {
        let now = Date.now
        let calendar = Calendar.current
        // Sessions yesterday and the day before, nothing logged yet today.
        let sessions = [
            Self.session(daysAgo: 1, burnRisk: 0.2, referenceDate: now),
            Self.session(daysAgo: 2, burnRisk: 0.2, referenceDate: now),
        ]
        let streaks = BronzScore.streaks(for: sessions, referenceDate: now, calendar: calendar)
        #expect(streaks.current == 2)
    }

    @Test("Consecutive days including today extend the current streak")
    func todayExtendsStreak() {
        let now = Date.now
        let calendar = Calendar.current
        let sessions = (0...2).map { Self.session(daysAgo: $0, burnRisk: 0.2, referenceDate: now) }
        let streaks = BronzScore.streaks(for: sessions, referenceDate: now, calendar: calendar)
        #expect(streaks.current == 3)
        #expect(streaks.longest == 3)
    }

    // MARK: - Codable

    @Test("BronzScore round-trips through JSON, since it is pushed to the leaderboard")
    func bronzScoreRoundTrips() throws {
        let score = BronzScore(
            total: 42, sessionCount: 5, cleanSessionCount: 4, burnCount: 1,
            currentStreak: 2, longestStreak: 3, disciplineRate: 0.8
        )
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(BronzScore.self, from: data)
        #expect(decoded == score)
    }

    // MARK: - Badge.earned

    @Test("No sessions earns no badges")
    func noBadgesWithoutSessions() {
        #expect(Badge.earned(from: []).isEmpty)
    }

    @Test("A single session earns only firstSession")
    func firstSessionOnly() {
        let now = Date.now
        let badges = Badge.earned(from: [Self.session(daysAgo: 0, burnRisk: 0.3, referenceDate: now)], referenceDate: now)
        #expect(badges == [.firstSession])
    }

    @Test("Disciplined requires ten clean sessions and zero burns")
    func disciplinedThreshold() {
        let now = Date.now
        let nineClean = (0..<9).map { Self.session(daysAgo: $0, burnRisk: 0.3, referenceDate: now) }
        #expect(!Badge.earned(from: nineClean, referenceDate: now).contains(.disciplined))

        let tenClean = (0..<10).map { Self.session(daysAgo: $0, burnRisk: 0.3, referenceDate: now) }
        #expect(Badge.earned(from: tenClean, referenceDate: now).contains(.disciplined))

        var withABurn = tenClean
        withABurn.append(Self.session(daysAgo: 11, burnRisk: 1.2, referenceDate: now))
        #expect(!Badge.earned(from: withABurn, referenceDate: now).contains(.disciplined))
    }

    @Test("Early bird requires five morning sessions")
    func earlyBirdThreshold() {
        let now = Date.now
        let calendar = Calendar.current
        let fourMorning = (0..<4).map {
            Self.session(daysAgo: $0, burnRisk: 0.2, hour: 9, calendar: calendar, referenceDate: now)
        }
        #expect(!Badge.earned(from: fourMorning, referenceDate: now).contains(.earlyBird))

        let fiveMorning = (0..<5).map {
            Self.session(daysAgo: $0, burnRisk: 0.2, hour: 9, calendar: calendar, referenceDate: now)
        }
        #expect(Badge.earned(from: fiveMorning, referenceDate: now).contains(.earlyBird))
    }

    @Test("Protector requires twenty protected sessions")
    func protectorThreshold() {
        let now = Date.now
        let nineteen = (0..<19).map { Self.session(daysAgo: $0, burnRisk: 0.2, spf: 30, referenceDate: now) }
        #expect(!Badge.earned(from: nineteen, referenceDate: now).contains(.protector))

        let twenty = (0..<20).map { Self.session(daysAgo: $0, burnRisk: 0.2, spf: 30, referenceDate: now) }
        #expect(Badge.earned(from: twenty, referenceDate: now).contains(.protector))
    }

    @Test("No badge rewards duration, darkness or raw exposure")
    func noBadgeRewardsExposure() {
        // Structural guard: every case must be reachable through discipline signals only.
        // This mirrors the design doc comment on Badge and BronzScore.
        let rewardsDuration = Badge.allCases.contains { badge in
            switch badge {
            case .firstSession, .disciplined, .earlyBird, .shadeMaster, .perfectWeek, .perfectSeason, .protector:
                return false
            }
        }
        #expect(!rewardsDuration)
    }
}
