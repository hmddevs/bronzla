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

    /// The underlying failure, for showing to the user on their own device when they cannot
    /// reach a Mac to read the log. Deliberately not routed through `errorDescription`, which
    /// stays plain language, and never written to the unified log: framework errors can embed
    /// the request URL, and that carries the coordinates.
    var diagnosticDetail: String? {
        if case .network(let detail) = self { return detail }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .network:
            String(localized: "Could not reach the weather service. It may be your connection, or the service may be briefly unavailable.")
        case .noDataForLocation:
            String(localized: "No data found for this location.")
        case .notAuthorised:
            String(localized: "No permission to reach the weather service.")
        }
    }
}
