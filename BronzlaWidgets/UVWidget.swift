import SwiftUI
import WidgetKit

/// Home screen and Lock Screen UV readings.
///
/// Reads what the app last wrote to the shared container rather than fetching. See
/// `SharedUVSnapshot` for why. The timeline is short and shallow: UV changes hourly, and a
/// widget promising a number it cannot refresh is worse than one that admits its age.
struct UVWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BronzlaUVWidget", provider: UVTimelineProvider()) { entry in
            UVWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("UV Index")
        .description("The UV index where you are, and your safe time in the sun.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct UVEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedUVSnapshot?

    /// Shown in the widget gallery, where no real reading exists yet.
    static let placeholder = UVEntry(
        date: .now,
        snapshot: SharedUVSnapshot(
            uvIndex: 8,
            placeName: "Antalya",
            temperatureCelsius: 32,
            recommendedSeconds: 1500,
            skinTypeNumeral: "III",
            fetchedAt: .now
        )
    )
}

struct UVTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UVEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (UVEntry) -> Void) {
        completion(context.isPreview ? .placeholder : UVEntry(date: .now, snapshot: SharedUVSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVEntry>) -> Void) {
        let entry = UVEntry(date: .now, snapshot: SharedUVSnapshot.read())
        // Ask to be refreshed in an hour. The system decides whether to honour it, which is
        // exactly why the view states the reading's age rather than implying it is live.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct UVWidgetView: View {
    let entry: UVEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: SharedUVSnapshot? {
        guard let snapshot = entry.snapshot, !snapshot.isExpired else { return nil }
        return snapshot
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: - Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill")
                Text("UV")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let snapshot {
                Text(index(snapshot))
                    .font(.system(size: 46, weight: .light, design: .rounded))
                    .foregroundStyle(tint(snapshot))

                Text(snapshot.category.localisedTitle)
                    .font(.subheadline.weight(.medium))

                Spacer(minLength: 0)

                Text(snapshot.placeName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                unavailable
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            small

            if let snapshot {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("Safe time", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let seconds = snapshot.recommendedSeconds {
                        Text(duration(seconds))
                            .font(.title2.weight(.medium))
                        Text("Cilt tipi \(snapshot.skinTypeNumeral)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Yanma riski yok")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text(snapshot.fetchedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Lock screen

    private var circular: some View {
        Gauge(value: min(snapshot?.uvIndex ?? 0, 12), in: 0...12) {
            Image(systemName: "sun.max.fill")
        } currentValueLabel: {
            Text(snapshot.map { index($0) } ?? "--")
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("UV \(snapshot.map { index($0) } ?? "--")", systemImage: "sun.max.fill")
                .font(.headline)
            if let snapshot {
                Text(snapshot.category.localisedTitle)
                    .font(.caption)
                if let seconds = snapshot.recommendedSeconds {
                    Text("Safe: \(duration(seconds))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Veri yok")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label(
            snapshot.map { "UV \(index($0)) · \($0.category.localisedTitle)" } ?? "UV verisi yok",
            systemImage: "sun.max.fill"
        )
    }

    // MARK: - Shared

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("--")
                .font(.system(size: 46, weight: .light, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Open the app")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func index(_ snapshot: SharedUVSnapshot) -> String {
        Int(snapshot.uvIndex.rounded()).formatted()
    }

    private func duration(_ seconds: Double) -> String {
        let minutes = max(Int((seconds / 60).rounded()), 0)
        // Locale-aware: gives "25 min" / "1 hr 25 min" in English and "25 dk" / "1 sa 25 dk"
        // in Turkish, instead of hardcoding one language's abbreviations into both.
        var allowed: Set<Duration.UnitsFormatStyle.Unit> = []
        if minutes >= 60 { allowed.insert(.hours) }
        if minutes % 60 != 0 || minutes < 60 { allowed.insert(.minutes) }
        return Duration.seconds(minutes * 60).formatted(.units(allowed: allowed, width: .abbreviated))
    }

    /// Colours are declared here rather than imported from `Palette`, which lives in the app
    /// target. Duplicating five values beats pulling the design system into the extension.
    private func tint(_ snapshot: SharedUVSnapshot) -> Color {
        switch snapshot.category {
        case .low: Color(red: 0.24, green: 0.72, blue: 0.47)
        case .moderate: Color(red: 0.96, green: 0.78, blue: 0.24)
        case .high: Color(red: 0.96, green: 0.55, blue: 0.20)
        case .veryHigh: Color(red: 0.90, green: 0.29, blue: 0.26)
        case .extreme: Color(red: 0.60, green: 0.33, blue: 0.78)
        }
    }
}
