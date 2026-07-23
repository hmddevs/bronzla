import Foundation

/// "Tan Score": a score that rewards discipline, not exposure.
///
/// This is the most consequential design decision in the app, so it is worth stating plainly.
/// A tanning app that scores hours in the sun, or how dark someone got, pays people to burn.
/// Turkey has serious melanoma numbers on exactly the coasts this app is written for, and a
/// leaderboard ranked on exposure would push in the same direction as the culture that causes
/// them.
///
/// So the score rewards the opposite: sessions finished inside the recommended limit, sunscreen
/// worn, regular short sessions rather than marathons, and above all never burning. Exceeding
/// the limit costs points. The competitive pull and the safe behaviour therefore point the same
/// way, and "14 gün, sıfır yanık" is a better thing to post than "six hours on the beach".
///
/// Pure and dependency-free, like `ExposureCalculator`, so the arithmetic can be tested without
/// a store, a clock or a simulator.
struct BronzScore: Equatable, Sendable {
    let total: Int
    let sessionCount: Int
    let cleanSessionCount: Int
    let burnCount: Int
    let currentStreak: Int
    let longestStreak: Int
    /// Proportion of sessions completed without exceeding the burn threshold, 0 to 1.
    let disciplineRate: Double

    static let zero = BronzScore(
        total: 0, sessionCount: 0, cleanSessionCount: 0, burnCount: 0,
        currentStreak: 0, longestStreak: 0, disciplineRate: 0
    )

    // MARK: - Weights

    /// A session that stayed under the erythemal threshold.
    static let cleanSessionPoints = 10
    /// Sunscreen actually worn. Small, because SPF is claimed rather than measured.
    static let protectedSessionPoints = 5
    /// Consecutive days. Consistency is how a tan is built without burning, so the game and the
    /// biology agree rather than fighting.
    static let streakDayPoints = 3
    /// Passing one MED. Deliberately larger than any single reward, so no amount of grinding
    /// makes burning worth it.
    static let burnPenalty = 25

    // MARK: - Calculation

    static func make(from sessions: [TanSession], referenceDate: Date = .now, calendar: Calendar = .current) -> BronzScore {
        guard !sessions.isEmpty else { return .zero }

        let clean = sessions.filter { $0.burnRisk < 1.0 }
        let burns = sessions.count - clean.count
        let protected = sessions.filter { $0.spf > 1 }.count
        let streaks = streaks(for: sessions, referenceDate: referenceDate, calendar: calendar)

        let raw = clean.count * cleanSessionPoints
            + protected * protectedSessionPoints
            + streaks.longest * streakDayPoints
            - burns * burnPenalty

        return BronzScore(
            total: max(0, raw),
            sessionCount: sessions.count,
            cleanSessionCount: clean.count,
            burnCount: burns,
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            disciplineRate: Double(clean.count) / Double(sessions.count)
        )
    }

    /// Consecutive calendar days containing at least one session.
    ///
    /// The current streak counts back from today, and tolerates today being empty: someone who
    /// tanned yesterday but not yet today has not broken anything, and telling them they have
    /// at 9am would be both wrong and a nudge to go outside.
    static func streaks(for sessions: [TanSession], referenceDate: Date = .now, calendar: Calendar = .current) -> (current: Int, longest: Int) {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }).sorted()
        guard let first = days.first else { return (0, 0) }

        var longest = 1
        var run = 1
        for (previous, day) in zip(days, days.dropFirst()) {
            if calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }

        let today = calendar.startOfDay(for: referenceDate)
        var current = 0
        var cursor = today
        if !days.contains(today) {
            cursor = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }
        while days.contains(cursor), cursor >= first {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return (current, longest)
    }

    /// Headline shown on the share card. Earned language only: nothing here congratulates
    /// someone for time spent, only for not burning.
    var title: LocalizedStringResource {
        switch (burnCount, sessionCount) {
        // Nobody with no sessions has earned a judgement. Without this the switch fell through
        // to "Needs care", which told a brand new user they had done something wrong before
        // they had done anything at all, and inverted the rule that this score only ever
        // responds to actual behaviour.
        case (_, 0): "No sessions yet"
        case (0, 10...): "Flawless season"
        case (0, 1...): "Zero burns"
        case (_, _) where disciplineRate >= 0.8: "Disciplined"
        case (_, _) where disciplineRate >= 0.5: "Improving"
        default: "Needs care"
        }
    }
}
