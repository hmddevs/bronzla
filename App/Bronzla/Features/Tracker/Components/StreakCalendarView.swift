import SwiftUI

/// Current month at a glance: one dot per day that had a session, tinted by that day's worst
/// burn risk. The streak headline reuses `InsightsSummary.streaks` so the number here and the
/// one on the insights screen can never disagree.
struct StreakCalendarView: View {
    let sessions: [TanSession]
    var referenceDate: Date = .now
    var calendar: Calendar = .current

    private var currentStreak: Int {
        InsightsSummary.streaks(for: sessions, referenceDate: referenceDate, calendar: calendar).current
    }

    /// Highest burn risk logged on each calendar day.
    private var riskByDay: [Date: Double] {
        sessions.reduce(into: [:]) { result, session in
            let day = calendar.startOfDay(for: session.startedAt)
            result[day] = max(result[day] ?? 0, session.burnRisk)
        }
    }

    private var monthDays: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: referenceDate) else { return [] }
        var days: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// Empty cells before the first of the month, so weekday columns line up.
    private var leadingBlankCount: Int {
        guard let first = monthDays.first else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(currentStreak.formatted())
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("day streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(referenceDate.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: Spacing.s) {
                ForEach(0..<leadingBlankCount, id: \.self) { _ in
                    Color.clear.frame(height: 28)
                }
                ForEach(monthDays, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .cardSurface()
    }

    private func dayCell(_ day: Date) -> some View {
        let dayStart = calendar.startOfDay(for: day)
        let risk = riskByDay[dayStart]

        return VStack(spacing: Spacing.xs) {
            Text(calendar.component(.day, from: day).formatted())
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(calendar.isDateInToday(day) ? Color.primary : .secondary)

            Circle()
                .fill(risk.map { Palette.colour(for: band(forBurnRisk: $0)) } ?? .clear)
                .frame(width: 6, height: 6)
        }
        .frame(height: 28)
        .accessibilityElement(children: .combine)
    }

    /// Maps a burn-risk fraction (dose ÷ MED, typically 0 to 1.5) onto the WHO UV bands so the
    /// dot can reuse `Palette.colour(for:)`. This is deliberately its own scale: `UVCategory`'s
    /// thresholds are calibrated for raw UV index values, not for a dose fraction.
    private func band(forBurnRisk risk: Double) -> UVCategory {
        switch risk {
        case ..<0.5: .low
        case ..<0.8: .moderate
        case ..<1.0: .high
        case ..<1.3: .veryHigh
        default: .extreme
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date.now
    let sessions = (0..<5).map { offset -> TanSession in
        let start = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        return TanSession(
            startedAt: start,
            endedAt: start.addingTimeInterval(1800),
            placeName: "Sahil",
            spf: 30,
            skinType: .iii,
            erythemalDose: Double(offset) * 90,
            peakUVIndex: 8
        )
    }
    return StreakCalendarView(sessions: sessions)
        .padding()
}
