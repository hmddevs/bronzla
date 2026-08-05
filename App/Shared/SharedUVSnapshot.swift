import Foundation

/// The last known UV reading, shared between the app and its widget extension.
///
/// Compiled into both targets, so it stays minimal: no `UVReport`, no `SkinType`, no
/// `ExposureCalculator`. Only what a widget can actually draw.
///
/// The widget reads rather than fetches. A widget that called WeatherKit itself would double
/// the call budget and the battery cost to arrive at the same number the app already has, and
/// widget refreshes are budgeted by the system anyway, so it would frequently be *staler* than
/// what the app last wrote.
struct SharedUVSnapshot: Codable, Sendable, Equatable {
    let uvIndex: Double
    let placeName: String
    let temperatureCelsius: Double
    /// Recommended session length in seconds for the active profile, or `nil` when there is no
    /// meaningful UV to tan in.
    let recommendedSeconds: Double?
    let skinTypeNumeral: String
    /// When the reading was fetched, so the widget can say how old it is rather than implying
    /// it is live.
    let fetchedAt: Date

    static let appGroup = "group.com.hmdcorp.bronzla"
    private static let filename = "latest-uv.json"

    /// Container URL, or `nil` when the App Group is unavailable. That happens on an unsigned
    /// build, so every caller treats it as an ordinary empty state rather than an error: a
    /// missing widget reading is not worth degrading the app over.
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: filename)
    }

    static func write(_ snapshot: SharedUVSnapshot) {
        guard let fileURL else { return }
        guard let data = try? JSONEncoder.shared.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func read() -> SharedUVSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder.shared.decode(SharedUVSnapshot.self, from: data)
    }

    /// A reading this old should not be presented as current. Half a day covers an overnight
    /// gap without ever showing yesterday afternoon's peak as though it were now.
    var isExpired: Bool {
        Date.now.timeIntervalSince(fetchedAt) > 12 * 3600
    }

    var category: SharedUVCategory { SharedUVCategory(uvIndex: uvIndex) }
}

/// WHO bands, duplicated in the shared layer rather than importing `UVCategory`, which carries
/// `LocalizedStringResource` copy the widget does not need. Thresholds are fixed by the WHO and
/// will not drift apart.
enum SharedUVCategory: Sendable {
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

    /// Localised band name. Was `turkishTitle` returning hardcoded Turkish, which leaked into
    /// the widget and every Siri response regardless of the device language.
    var localisedTitle: String {
        switch self {
        case .low: String(localized: "Low")
        case .moderate: String(localized: "Moderate")
        case .high: String(localized: "High")
        case .veryHigh: String(localized: "Very high")
        case .extreme: String(localized: "Extreme")
        }
    }
}

extension JSONEncoder {
    static let shared: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
