import SwiftData
import SwiftUI

/// "Tan Tracker": every logged session, the current streak, and a way in to the deeper
/// statistics on `InsightsView`.
struct TrackerView: View {
    @Query(sort: \TanSession.startedAt, order: .reverse) private var sessions: [TanSession]
    @State private var isPresentingManualEntry = false

    private let calendar = Calendar.current

    /// Sessions grouped by the first day of their month, most recent month first.
    private var groupedByMonth: [(monthStart: Date, sessions: [TanSession])] {
        let groups = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .month, for: session.startedAt)?.start ?? session.startedAt
        }
        return groups
            .sorted { $0.key > $1.key }
            .map { (monthStart: $0.key, sessions: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            StreakCalendarView(sessions: sessions)
                                .accessibilityIdentifier("tracker.streakCalendar")
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        ForEach(groupedByMonth, id: \.monthStart) { group in
                            Section(monthTitle(group.monthStart)) {
                                ForEach(group.sessions) { session in
                                    NavigationLink {
                                        SessionDetailView(session: session)
                                    } label: {
                                        SessionRow(session: session)
                                    }
                                }
                            }
                        }

                        Section {
                            // Every row above shows a burn-risk figure, so the disclaimer
                            // belongs to the list as a whole, not just the detail screen.
                            MedicalDisclaimer()
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("Tan Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        InsightsView()
                    } label: {
                        Label("Insights", systemImage: "chart.bar.xaxis")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingManualEntry = true
                    } label: {
                        Label("Add a session", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingManualEntry) {
                ManualSessionEntryView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No sessions yet", systemImage: "calendar.badge.clock")
        } description: {
            Text("Your sessions appear here once you use the timer.")
        } actions: {
            Button("Add a session") { isPresentingManualEntry = true }
        }
    }

    private func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}

/// One row in the session list: date, place, duration and burn risk at a glance.
private struct SessionRow: View {
    let session: TanSession

    var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(session.startedAt.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                Text(session.placeName.isEmpty ? "Konum belirtilmedi" : session.placeName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(SafeExposureCard.format(session.duration))
                    .font(.subheadline)
                    .monospacedDigit()
                Text(session.burnRisk.formatted(.percent.precision(.fractionLength(0)).locale(.app)))
                    .font(.footnote)
                    .foregroundStyle(session.burnRisk >= 1 ? Palette.colour(for: .veryHigh) : .secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TrackerView()
        .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
