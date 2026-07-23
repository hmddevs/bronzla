import CoreLocation
import Foundation
import Observation
import OSLog
import WeatherKit

/// UV data for the watch, fetched independently of the phone.
///
/// The watch calls WeatherKit and CoreLocation itself rather than relying on WatchConnectivity.
/// That is the whole point of a watch app here: someone swims, runs or walks the beach without
/// their phone, and a companion that goes blank the moment the phone is out of range is worse
/// than no companion. Independence costs a second WeatherKit call and buys a device that works
/// on its own.
///
/// Skin type comes from `UserDefaults` seeded by the phone through the shared app group where
/// available, falling back to type III, which is the most common in this market and the safer
/// assumption of the two most likely.
@MainActor
@Observable
final class WatchUVModel {

    enum Phase: Equatable {
        case idle
        case loading
        case loaded(uvIndex: Double, placeName: String, temperature: Measurement<UnitTemperature>)
        case denied
        case failed
    }

    private(set) var phase: Phase = .idle

    private let logger = Logger(subsystem: "com.hmdcorp.bronzla.watch", category: "WatchUV")
    private let manager = CLLocationManager()
    private let service = WeatherService.shared

    var skinType: SkinType {
        get {
            let raw = UserDefaults.standard.integer(forKey: Self.skinTypeKey)
            return SkinType(rawValue: raw) ?? .iii
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.skinTypeKey) }
    }

    var spf: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.spfKey)
            return stored > 0 ? stored : 30
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.spfKey) }
    }

    private static let skinTypeKey = "bronzla.watch.skinType"
    private static let spfKey = "bronzla.watch.spf"

    var uvIndex: Double? {
        if case .loaded(let uvIndex, _, _) = phase { return uvIndex }
        return nil
    }

    var recommendedSession: Duration? {
        guard let uvIndex else { return nil }
        return ExposureCalculator.recommendedSession(uvIndex: uvIndex, skinType: skinType, spf: spf)
    }

    var category: UVCategory? { uvIndex.map(UVCategory.init(uvIndex:)) }

    func refresh() async {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            phase = .denied
            return
        default:
            break
        }

        phase = .loading

        do {
            var coordinate: CLLocationCoordinate2D?
            for try await update in CLLocationUpdate.liveUpdates(.default) {
                if update.authorizationDenied {
                    phase = .denied
                    return
                }
                if let location = update.location {
                    coordinate = location.coordinate
                    break
                }
            }

            guard let coordinate else {
                phase = .failed
                return
            }

            let weather = try await service.weather(
                for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )

            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            let name = placemarks?.first?.locality ?? ""

            phase = .loaded(
                uvIndex: Double(weather.currentWeather.uvIndex.value),
                placeName: name,
                temperature: weather.currentWeather.temperature
            )
        } catch {
            logger.error("Watch refresh failed: \((error as NSError).domain, privacy: .public) code \((error as NSError).code, privacy: .public); detail: \(error.localizedDescription, privacy: .private)")
            phase = .failed
        }
    }
}
