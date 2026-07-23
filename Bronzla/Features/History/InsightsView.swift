import Charts
import SwiftData
import SwiftUI

/// Aggregation maths, held apart from the view so it is testable without SwiftData.
///
/// `TanSession` and `UserProfile` are SwiftData model classes, not value types, but `make(from:profile:)`
/// only reads their stored properties synchronously on the caller's own isolation domain; it never
/// crosses an actor boundary, so no `Sendable` conformance is needed here.
struct InsightsSummary: Equatable {
    struct WeeklyMinutes: Equatable, Identifiable {
        let weekStart: Date
        let minutes: Double
        var id: Date { weekStart }
    }

    let sessionCount: Int
    let totalTimeThisMonth: Duration
    let totalTimeAllTime: Duration
    let longestStreakDays: Int
    let currentStreakDays: Int
    let totalEstimatedVitaminD: Double
    let highBurnRiskSessionCount: Int
    /// Minutes per week for the last 8 weeks, oldest first.
    let weeklyMinutes: [WeeklyMinutes]

    static let empty = InsightsSummary(
        sessionCount: 0,
        totalTimeThisMonth: .zero,
        totalTimeAllTime: .zero,
        longestStreakDays: 0,
        currentStreakDays: 0,
        totalEstimatedVitaminD: 0,
        highBurnRiskSessionCount: 0,
        weeklyMinutes: []
    )

    /// Default exposed-body fraction used when no profile is available yet, matching
    /// `UserProfile`'s own default so an unset profile does not skew the estimate.
    private static let defaultExposedBodyFraction: Double = 0.6

    static func make(
        from sessions: [TanSession],
        profile: UserProfile?,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> InsightsSummary {
        guard !sessions.isEmpty else { return .empty }

        let exposedBodyFraction = profile?.exposedBodyFraction ?? defaultExposedBodyFraction

        let totalTimeAllTime = sessions.reduce(Duration.zero) { $0 + $1.duration }

        let thisMonthSessions = sessions.filter {
            calendar.isDate($0.startedAt, equalTo: referenceDate, toGranularity: .month)
        }
        let totalTimeThisMonth = thisMonthSessions.reduce(Duration.zero) { $0 + $1.duration }

        let totalVitaminD = sessions.reduce(0.0) { total, session in
            total + ExposureCalculator.estimatedVitaminD(
                dose: session.erythemalDose,
                skinType: session.skinType,
                exposedBodyFraction: exposedBodyFraction
            )
        }

        let highRiskCount = sessions.filter { $0.burnRisk > 1.0 }.count
        let (current, longest) = streaks(for: sessions, referenceDate: referenceDate, calendar: calendar)
        let weekly = weeklyMinutes(for: sessions, referenceDate: referenceDate, calendar: calendar)

        return InsightsSummary(
            sessionCount: sessions.count,
            totalTimeThisMonth: totalTimeThisMonth,
            totalTimeAllTime: totalTimeAllTime,
            longestStreakDays: longest,
            currentStreakDays: current,
            totalEstimatedVitaminD: totalVitaminD,
            highBurnRiskSessionCount: highRiskCount,
            weeklyMinutes: weekly
        )
    }

    // MARK: - Streaks

    /// Consecutive-day streaks, computed from distinct calendar days that contain a session.
    /// A public static function rather than a private detail, so `StreakCalendarView` can share
    /// the exact same rule the insights screen uses; the two headline numbers must never disagree.
    static func streaks(
        for sessions: [TanSession],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> (current: Int, longest: Int) {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }).sorted()
        guard let mostRecent = days.last else { return (0, 0) }

        var longest = 1
        var run = 1
        for index in 1..<days.count {
            let previousDay = days[index - 1]
            if calendar.date(byAdding: .day, value: 1, to: previousDay) == days[index] {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }

        // A streak only counts as "current" if it reaches today or yesterday; older activity
        // does not count as ongoing, however long the run once was.
        let today = calendar.startOfDay(for: referenceDate)
        let gapFromToday = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? .max
        guard gapFromToday <= 1 else { return (0, longest) }

        var current = 1
        var cursor = mostRecent
        for day in days.reversed().dropFirst() {
            guard let expectedPrevious = calendar.date(byAdding: .day, value: -1, to: cursor),
                  expectedPrevious == day else { break }
            current += 1
            cursor = day
        }

        return (current, longest)
    }

    // MARK: - Weekly chart

    /// Minutes spent per week over the last 8 weeks, oldest first, feeding the bar chart.
    static func weeklyMinutes(
        for sessions: [TanSession],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [WeeklyMinutes] {
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }

        return (0..<8).reversed().compactMap { offset -> WeeklyMinutes? in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart),
                  let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else {
                return nil
            }
            let minutes = sessions
                .filter { $0.startedAt >= weekStart && $0.startedAt < weekEnd }
                .reduce(0.0) { $0 + $1.duration.seconds / 60 }
            return WeeklyMinutes(weekStart: weekStart, minutes: minutes)
        }
    }
}

/// "Insights": what all the logged sessions add up to.
struct InsightsView: View {
    @Query(sort: \TanSession.startedAt, order: .reverse) private var sessions: [TanSession]
    @Query private var profiles: [UserProfile]
    @State private var activeStore = ActiveProfileStore()

    private var profile: UserProfile? { activeStore.profile(in: profiles) }

    private var summary: InsightsSummary {
        InsightsSummary.make(from: sessions, profile: profile)
    }

    private var score: BronzScore { BronzScore.make(from: sessions) }
    private var badges: [Badge] { Badge.earned(from: sessions) }
    private var placeCount: Int {
        Set(sessions.map(\.placeName).filter { !$0.isEmpty }).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No data yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("As you log sessions, your time, streak and estimated vitamin D will appear here.")
                    )
                    .padding(.top, Spacing.xxl)
                } else {
                    seasonCard
                    timeCard
                    streakCard
                    weeklyChartCard
                    vitaminDCard
                    if summary.highBurnRiskSessionCount > 0 {
                        burnRiskCard
                    }
                    MedicalDisclaimer()
                }
            }
            .padding(Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Yaz Özeti

    private var seasonCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text(String(localized: score.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                ShareCardButton(
                    content: .season(score: score, hours: summary.totalTimeAllTime.seconds / 3600, places: placeCount),
                    profileName: profile?.name ?? ""
                )
                .labelStyle(.iconOnly)
            }

            Text("\(score.total)")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("Tan Score")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s) {
                        ForEach(badges) { badge in
                            badgePill(badge)
                        }
                    }
                }
            }
        }
        .cardSurface()
    }

    private func badgePill(_ badge: Badge) -> some View {
        Label {
            Text(badge.title)
        } icon: {
            Image(systemName: badge.symbol)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(Palette.cardElevated, in: .capsule)
        .accessibilityLabel(Text(badge.title))
        .accessibilityHint(Text(badge.detail))
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Time in the sun")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            statRow("This month", SafeExposureCard.format(summary.totalTimeThisMonth))
            Divider()
            statRow("Total", SafeExposureCard.format(summary.totalTimeAllTime))
            Divider()
            statRow("Sessions", summary.sessionCount.formatted())
        }
        .cardSurface()
    }

    private var streakCard: some View {
        HStack(spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(summary.currentStreakDays.formatted())
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("day streak")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(summary.longestStreakDays.formatted())
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("longest streak")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cardSurface()
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Minutes per week")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart(summary.weeklyMinutes) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Minutes", week.minutes)
                )
                .foregroundStyle(.tint)
                .cornerRadius(4)
            }
            .frame(height: 160)
        }
        .cardSurface()
    }

    private var vitaminDCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Estimated vitamin D")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(Int(summary.totalEstimatedVitaminD.rounded())) IU")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("This is a rough estimate; age, body composition and previous sun exposure are not taken into account.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }

    private var burnRiskCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("A gentle reminder", systemImage: "sun.max.trianglebadge.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.colour(for: .veryHigh))

            Text("You passed the burn threshold in \(summary.highBurnRiskSessionCount) sessions. A shorter session or a higher SPF would help.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }

    private func statRow(_ title: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
    .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
