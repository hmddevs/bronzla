import SwiftUI

/// The whole watch app: current UV, what it means, how long is safe.
///
/// One screen, no tabs, no history. A watch glance lasts about two seconds, and everything the
/// phone app offers beyond this number would be unreadable at that size and unusable at that
/// pace. The tracker, forecast and photos stay on the phone where they belong.
struct WatchDashboardView: View {
    @Environment(WatchUVModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    switch model.phase {
                    case .idle, .loading:
                        ProgressView()
                            .padding(.top, 24)
                    case .loaded(_, let placeName, let temperature):
                        reading
                        safeTime
                        conditions(placeName: placeName, temperature: temperature)
                        WatchWeatherAttributionView()
                        disclaimer
                    case .denied:
                        message("Konum izni yok", detail: "iPhone'da Bronzla'ya konum izni verin.")
                    case .failed:
                        message("Could not fetch data", detail: "Check your connection and try again.")
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Bronzla")
            .task { await model.refresh() }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var reading: some View {
        if let uvIndex = model.uvIndex, let category = model.category {
            VStack(spacing: 2) {
                Text("UV")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(Int(uvIndex.rounded()).formatted())
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .foregroundStyle(tint(category))

                Text(category.title)
                    .font(.caption)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var safeTime: some View {
        VStack(spacing: 2) {
            if let session = model.recommendedSession {
                Text(format(session))
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
                Text("safe time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Yanma riski yok")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary, in: .rect(cornerRadius: 12))
    }

    private func conditions(placeName: String, temperature: Measurement<UnitTemperature>) -> some View {
        HStack {
            if !placeName.isEmpty {
                Text(placeName)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(temperature.formatted(.measurement(width: .narrow, usage: .weather)))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var disclaimer: some View {
        Text("Not medical advice.")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await model.refresh() }
            }
            .padding(.top, 4)
        }
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private func format(_ duration: Duration) -> String {
        let minutes = max(Int((duration.seconds / 60).rounded()), 0)
        // Locale-aware: gives "25 min" / "1 hr 25 min" in English and "25 dk" / "1 sa 25 dk"
        // in Turkish, instead of hardcoding one language's abbreviations into both.
        var allowed: Set<Duration.UnitsFormatStyle.Unit> = []
        if minutes >= 60 { allowed.insert(.hours) }
        if minutes % 60 != 0 || minutes < 60 { allowed.insert(.minutes) }
        return Duration.seconds(minutes * 60).formatted(.units(allowed: allowed, width: .abbreviated))
    }

    /// Repeated from `Palette` rather than shared: the design system lives in the iOS target
    /// and pulling it across for five colours would drag SwiftUI layout code with it.
    private func tint(_ category: UVCategory) -> Color {
        switch category {
        case .low: Color(red: 0.24, green: 0.72, blue: 0.47)
        case .moderate: Color(red: 0.96, green: 0.78, blue: 0.24)
        case .high: Color(red: 0.96, green: 0.55, blue: 0.20)
        case .veryHigh: Color(red: 0.90, green: 0.29, blue: 0.26)
        case .extreme: Color(red: 0.60, green: 0.33, blue: 0.78)
        }
    }
}
