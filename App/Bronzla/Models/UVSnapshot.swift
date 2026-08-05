import Foundation

/// WHO ultraviolet index bands. Thresholds are fixed by the World Health Organization's
/// "Global Solar UV Index: A Practical Guide" and must not be tuned for aesthetics.
enum UVCategory: Int, CaseIterable, Sendable, Comparable {
    case low, moderate, high, veryHigh, extreme

    init(uvIndex: Double) {
        switch uvIndex {
        case ..<3: self = .low
        case ..<6: self = .moderate
        case ..<8: self = .high
        case ..<11: self = .veryHigh
        default: self = .extreme
        }
    }

    static func < (lhs: UVCategory, rhs: UVCategory) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        case .veryHigh: "Very high"
        case .extreme: "Extreme"
        }
    }

    var advice: LocalizedStringResource {
        switch self {
        case .low: "No protection needed. You can stay outside safely."
        case .moderate: "Stay in the shade around midday and apply SPF 30."
        case .high: "Protection is essential. Prefer the shade between 11.00 and 16.00."
        case .veryHigh: "Take extra care. Wear a hat and sunglasses, and use SPF 50."
        case .extreme: "Avoid the sun. Skin can burn within minutes."
        }
    }

    /// Whether protection is required at all. Drives whether the timer offers a session.
    var requiresProtection: Bool { self >= .moderate }
}

/// A point-in-time reading for one place. Value type: cheap to cache, diff and test.
struct UVSnapshot: Sendable, Equatable, Codable {
    let uvIndex: Double
    let temperature: Measurement<UnitTemperature>
    /// SF Symbol name supplied by the weather source, e.g. `sun.max`.
    let conditionSymbol: String
    let isDaylight: Bool
    let sunrise: Date?
    let sunset: Date?
    /// When the *reading* is valid for, not when it was fetched.
    let observedAt: Date

    var category: UVCategory { UVCategory(uvIndex: uvIndex) }
}

struct HourlyUV: Sendable, Equatable, Codable, Identifiable {
    let date: Date
    let uvIndex: Double
    let temperature: Measurement<UnitTemperature>
    let isDaylight: Bool

    var id: Date { date }
    var category: UVCategory { UVCategory(uvIndex: uvIndex) }
}

struct DailyUV: Sendable, Equatable, Codable, Identifiable {
    let date: Date
    /// Peak UV index for the day, which is what a sunbather actually plans around.
    let maxUVIndex: Double
    let highTemperature: Measurement<UnitTemperature>
    let lowTemperature: Measurement<UnitTemperature>
    let conditionSymbol: String
    let sunrise: Date?
    let sunset: Date?

    var id: Date { date }
    var category: UVCategory { UVCategory(uvIndex: maxUVIndex) }
}

/// Where a reading came from. Surfaced in the UI so the user is never misled about freshness.
enum UVDataSource: String, Sendable, Codable {
    /// Fetched from the network within this session.
    case live
    /// Read from the on-disk cache because the network was unavailable.
    case cached
    /// Generated locally. Previews, tests and simulator runs only.
    case sample
}

/// Everything one screen refresh needs, so the UI makes a single call and never
/// juggles three independent loading states.
struct UVReport: Sendable, Equatable, Codable {
    let placeName: String
    let current: UVSnapshot
    let hourly: [HourlyUV]
    let daily: [DailyUV]
    let source: UVDataSource
    /// When this report was retrieved from the network. Drives the "x min ago" label.
    let fetchedAt: Date

    /// A cached report older than this is worth warning about; UV moves fast near noon.
    static let stalenessThreshold: TimeInterval = 60 * 60

    var isStale: Bool { Date.now.timeIntervalSince(fetchedAt) > Self.stalenessThreshold }
}
