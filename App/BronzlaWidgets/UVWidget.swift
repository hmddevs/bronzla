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

                // Reflowed into a two-line footer rather than appended as a third: systemSmall
                // has no spare height, so the attribution shares the placeName's row group
                // instead of adding a fresh block below it.
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.placeName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    weatherAttribution
                }
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
                        Text("Skin type \(snapshot.skinTypeNumeral)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No burn risk")
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

    // accessoryCircular is a single glyph and a gauge ring; there is physically no room for
    // attribution text here, so it is deliberately skipped rather than crammed in.
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
                    // Attribution rides on the existing "Safe:" line rather than adding a
                    // fourth: accessoryRectangular already runs three lines at its densest,
                    // and a lock screen widget has no room to grow past that.
                    HStack(spacing: 4) {
                        Text("Safe: \(duration(seconds))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        weatherAttribution
                    }
                } else {
                    weatherAttribution
                }
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // accessoryInline is a single line of system-rendered text next to the glyph on the Lock
    // Screen; there is no room for a second phrase, so attribution is deliberately skipped here.
    @ViewBuilder
    private var inline: some View {
        if let snapshot {
            Label(String(localized: "UV \(index(snapshot)) · \(snapshot.category.localisedTitle)"), systemImage: "sun.max.fill")
        } else {
            Label(String(localized: "No UV data"), systemImage: "sun.max.fill")
        }
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

    /// WeatherKit trademark text mark. Widgets cannot open a URL from an arbitrary subview, so
    /// the linked, full attribution stays in the app; this compact mark is what Apple's
    /// constrained-surface guidance allows in its place. `.verbatim` because a trademark is not
    /// translated between locales.
    private var weatherAttribution: some View {
        Text(verbatim: "Weather")
            .font(.caption2)
            .foregroundStyle(.tertiary)
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
