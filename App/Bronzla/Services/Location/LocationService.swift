import CoreLocation
import Foundation
import Observation
import OSLog

/// Resolves the user's coordinate and a human-readable place name.
///
/// Uses `CLLocationUpdate.liveUpdates` rather than `CLLocationManagerDelegate`. The delegate
/// protocol is not actor-annotated, so bridging it onto the main actor means smuggling a
/// main-actor-isolated object through a `nonisolated` callback, which Swift 6 correctly rejects
/// as a data race. The async sequence carries `Sendable` values and needs no bridge at all.
///
/// `CLLocationManager` is still held, but only to read and request authorisation, which is
/// main-actor work and never crosses an isolation boundary.
@MainActor
@Observable
final class LocationService {

    enum Status: Equatable {
        case idle
        case requestingPermission
        case locating
        case resolved(Place)
        case denied
        case failed(String)
    }

    struct Place: Equatable, Sendable {
        let coordinate: CLLocationCoordinate2D
        let name: String

        static func == (lhs: Place, rhs: Place) -> Bool {
            lhs.name == rhs.name
                && lhs.coordinate.latitude == rhs.coordinate.latitude
                && lhs.coordinate.longitude == rhs.coordinate.longitude
        }
    }

    private(set) var status: Status = .idle

    /// Set when the user picks a place by hand. Overrides GPS until cleared, which is what
    /// someone checking tomorrow's Bodrum forecast from Istanbul actually wants.
    var manualPlace: Place? {
        didSet {
            if let manualPlace {
                updateTask?.cancel()
                status = .resolved(manualPlace)
            }
        }
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "LocationService")
    private var updateTask: Task<Void, Never>?

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    /// Current place if known, GPS or manual.
    var place: Place? {
        if let manualPlace { return manualPlace }
        if case .resolved(let place) = status { return place }
        return nil
    }

    /// Requests permission if needed, then a single fix. Safe to call repeatedly: an in-flight
    /// request is reused rather than restarted, so a view appearing twice does not spawn two
    /// location streams.
    func requestLocation() {
        guard manualPlace == nil else { return }
        guard updateTask == nil || updateTask?.isCancelled == true else { return }

        switch manager.authorizationStatus {
        case .denied, .restricted:
            status = .denied
            return
        case .notDetermined:
            status = .requestingPermission
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            status = .locating
        @unknown default:
            break
        }

        startUpdates()
    }

    // MARK: - Private

    /// Takes the first usable fix and stops. Continuous tracking would drain battery for no
    /// benefit: UV does not change meaningfully as someone walks along a beach.
    private func startUpdates() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }
            defer { self.updateTask = nil }

            do {
                for try await update in CLLocationUpdate.liveUpdates(.default) {
                    if Task.isCancelled || self.manualPlace != nil { return }

                    if update.authorizationDenied || update.authorizationDeniedGlobally {
                        self.status = .denied
                        return
                    }

                    if update.authorizationRequestInProgress {
                        self.status = .requestingPermission
                        continue
                    }

                    guard let location = update.location else {
                        if update.locationUnavailable { self.status = .locating }
                        continue
                    }

                    let name = await self.placeName(for: location)
                    guard !Task.isCancelled, self.manualPlace == nil else { return }
                    self.status = .resolved(Place(coordinate: location.coordinate, name: name))
                    return
                }
            } catch {
                self.logger.error("Location stream failed: \((error as NSError).domain, privacy: .public) code \((error as NSError).code, privacy: .public); detail: \(error.localizedDescription, privacy: .private)")
                // A failed fix while a place is already on screen must not blank the dashboard.
                guard self.place == nil else { return }
                self.status = .failed(String(localized: "Could not determine your location."))
            }
        }
    }

    /// Reverse geocodes to a district plus city, e.g. "Konyaaltı, Antalya", which is how
    /// Turkish users describe where they are. Falls back to coordinates rather than failing.
    private func placeName(for location: CLLocation) async -> String {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return Self.coordinateLabel(location) }
            let district = placemark.subLocality ?? placemark.locality
            let city = placemark.administrativeArea ?? placemark.locality
            return [district, city]
                .compactMap { $0 }
                .reduce(into: [String]()) { unique, part in
                    if !unique.contains(part) { unique.append(part) }
                }
                .joined(separator: ", ")
        } catch {
            logger.notice("Reverse geocode failed: \((error as NSError).domain, privacy: .public) code \((error as NSError).code, privacy: .public); detail: \(error.localizedDescription, privacy: .private)")
            return Self.coordinateLabel(location)
        }
    }

    private static func coordinateLabel(_ location: CLLocation) -> String {
        String(format: "%.2f, %.2f", location.coordinate.latitude, location.coordinate.longitude)
    }
}
