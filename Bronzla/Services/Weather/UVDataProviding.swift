import CoreLocation
import Foundation

/// Anything that can supply a UV report for a coordinate.
///
/// The abstraction exists for three practical reasons, not for testing purism:
/// WeatherKit is unavailable in SwiftUI previews, unavailable offline, and metered at
/// 500,000 calls per month. The cache lives *behind* this protocol so callers never branch
/// on where data came from; they read `UVReport.source` if they want to tell the user.
protocol UVDataProviding: Sendable {
    /// - Parameter placeName: Resolved place name, passed in because reverse geocoding is
    ///   the location layer's job, not the weather layer's.
    func report(for coordinate: CLLocationCoordinate2D, placeName: String) async throws -> UVReport
}

enum UVDataError: LocalizedError, Equatable {
    case network(String)
    case noDataForLocation
    case notAuthorised

    var errorDescription: String? {
        switch self {
        case .network:
            String(localized: "Could not fetch weather data. Check your connection.")
        case .noDataForLocation:
            String(localized: "No data found for this location.")
        case .notAuthorised:
            String(localized: "No permission to reach the weather service.")
        }
    }
}
