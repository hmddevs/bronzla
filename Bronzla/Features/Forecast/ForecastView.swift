import SwiftUI

/// "Forecast": the next 24 hours as a curve, then the ten-day outlook. Reuses `DashboardModel`
/// rather than a bespoke model; this screen coordinates the same single fetch, it just renders
/// more of the report that fetch already returns.
struct ForecastView: View {
    @Environment(\.uvProvider) private var uvProvider
    @Environment(LocationService.self) private var locationService

    @State private var dashboard = DashboardModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    switch dashboard.phase {
                    case .idle, .loading:
                        loadingState
                    case .loaded(let report):
                        content(for: report)
                    case .failed(let message, _):
                        failureState(message)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("Forecast")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await refresh(isManual: true) }
            .task(id: locationService.place) { await refresh() }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var loadingState: some View {
        ProgressView("Loading forecast…")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, Spacing.xxl)
    }

    @ViewBuilder
    private func failureState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Could not fetch the forecast", systemImage: "cloud.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") {
                Task { await refresh(isManual: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, Spacing.xxl)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for report: UVReport) -> some View {
        let hours = nextTwentyFourHours(from: report.hourly, now: .now)

        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(Self.peakWindowSummary(for: hours))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HourlyUVChart(hours: hours, now: .now)
                .accessibilityIdentifier("forecast.chart")
        }
        .cardSurface()

        VStack(alignment: .leading, spacing: 0) {
            Text("10 day outlook")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, Spacing.s)

            ForEach(Array(report.daily.enumerated()), id: \.element.id) { index, day in
                if index > 0 {
                    Divider()
                }
                DailyUVRow(day: day)
            }
        }
        .cardSurface()

        MedicalDisclaimer()

        WeatherAttributionView()
            .padding(.top, Spacing.s)
    }

    // MARK: - Derivation

    /// The next day's worth of readings starting from now, which is what a chart labelled
    /// "next 24 hours" should actually show rather than the full multi-day feed.
    private func nextTwentyFourHours(from hourly: [HourlyUV], now: Date) -> [HourlyUV] {
        Array(hourly.filter { $0.date >= now }.prefix(24))
    }

    /// The contiguous stretch of hours at or above WHO's "very high" threshold (UV 8), phrased
    /// as the window a sunbather should plan around. Pure and static so it is testable without
    /// standing up a view.
    static func peakWindowSummary(for hours: [HourlyUV], calendar: Calendar = .current) -> String {
        var bestRun: [HourlyUV] = []
        var currentRun: [HourlyUV] = []

        for hour in hours {
            if hour.uvIndex >= 8 {
                currentRun.append(hour)
                if currentRun.count > bestRun.count { bestRun = currentRun }
            } else {
                currentRun = []
            }
        }

        guard let first = bestRun.first, let last = bestRun.last else {
            return String(localized: "No extreme risk hours today")
        }

        // Each sample covers the hour that *follows* its timestamp, so a run whose last sample
        // is 15.00 stays risky until 16.00. Naming the last sample as the end would understate
        // the window by an hour, which on a safety surface is the wrong direction to be wrong.
        let end = last.date.addingTimeInterval(3600)
        return String(
            localized: "Highest risk hours: \(formattedHour(first.date, calendar: calendar)) - \(formattedHour(end, calendar: calendar))"
        )
    }

    private static func formattedHour(_ date: Date, calendar: Calendar) -> String {
        String(format: "%02d.00", calendar.component(.hour, from: date))
    }

    // MARK: - Actions

    private func refresh(isManual: Bool = false) async {
        guard let place = locationService.place else { return }
        dashboard.load(from: uvProvider, place: place, isManualRefresh: isManual)
    }
}

#Preview("High UV") {
    ForecastView()
        .environment(LocationService())
        .environment(\.uvProvider, SampleUVProvider(peakUVIndex: 10))
}
