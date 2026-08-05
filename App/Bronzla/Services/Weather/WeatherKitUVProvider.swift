import CoreLocation
import Foundation
import OSLog
import WeatherKit

/// Live UV data from Apple WeatherKit, with an on-disk fallback when the network is down.
///
/// Requires the `com.apple.developer.weatherkit` entitlement and an App ID with the WeatherKit
/// capability enabled. It does **not** work in SwiftUI previews or on an unsigned simulator
/// build, which is why `SampleUVProvider` exists.
struct WeatherKitUVProvider: UVDataProviding {
    private let service = WeatherService.shared
    private let cache: UVReportCache
    private let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "WeatherKit")

    init(cache: UVReportCache = .shared) {
        self.cache = cache
    }

    func report(for coordinate: CLLocationCoordinate2D, placeName: String) async throws -> UVReport {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let (current, hourly, daily) = try await service.weather(
                for: location,
                including: .current, .hourly, .daily
            )

            let report = UVReport(
                placeName: placeName,
                current: Self.snapshot(from: current, today: daily.first),
                hourly: Self.hourlySamples(from: hourly),
                daily: Self.dailySamples(from: daily),
                source: .live,
                fetchedAt: .now
            )

            await cache.store(report, for: coordinate)
            return report
        } catch {
            // Log the real error. `UVDataError.network` carries it but the user-facing string
            // deliberately does not, so without this the only signal from a device was a
            // generic "check your connection" that misdiagnoses a WeatherKit authorisation or
            // service failure as a networking one.
            // Domain, code and type are public because they are what actually identifies the
            // failure and carry nothing about the user. The free-text description stays private:
            // a WeatherKit or CoreLocation error can embed the request URL, which contains the
            // coordinates, and this app's whole privacy claim is that location never leaves the
            // device. `.private` is redacted in sysdiagnose and general log collection while
            // still readable on an attached device during development.
            let ns = error as NSError
            logger.error("""
                WeatherKit fetch failed: \(String(describing: type(of: error)), privacy: .public) \
                \(ns.domain, privacy: .public) code \(ns.code, privacy: .public); \
                detail: \(error.localizedDescription, privacy: .private)
                """)

            // Serving a stale reading beats serving nothing: someone on a beach with no signal
            // still needs to know roughly how strong the sun is. Freshness is surfaced in the UI.
            if let cached = await cache.report(for: coordinate) {
                return cached
            }

            #if DEBUG
            // WeatherKit needs a signed build with the entitlement, which a simulator run does
            // not have. Falling back keeps every screen explorable during development. The
            // report is tagged `.sample`, and the UI says so, so modelled numbers can never be
            // mistaken for a real reading. Release builds surface the error instead.
            return try await SampleUVProvider().report(for: coordinate, placeName: placeName)
            #else
            throw UVDataError.network(error.localizedDescription)
            #endif
        }
    }

    // MARK: - Mapping

    private static func snapshot(from current: CurrentWeather, today: DayWeather?) -> UVSnapshot {
        UVSnapshot(
            uvIndex: Double(current.uvIndex.value),
            temperature: current.temperature,
            conditionSymbol: current.symbolName,
            isDaylight: current.isDaylight,
            sunrise: today?.sun.sunrise,
            sunset: today?.sun.sunset,
            observedAt: current.date
        )
    }

    private static func hourlySamples(from forecast: Forecast<HourWeather>) -> [HourlyUV] {
        // Two days of hourly detail is all the forecast screen plots, and all WeatherKit
        // reliably returns. Trimming here keeps the cached payload small.
        let horizon = Date.now.addingTimeInterval(48 * 3600)
        return forecast
            .filter { $0.date >= Date.now.addingTimeInterval(-3600) && $0.date <= horizon }
            .map {
                HourlyUV(
                    date: $0.date,
                    uvIndex: Double($0.uvIndex.value),
                    temperature: $0.temperature,
                    isDaylight: $0.isDaylight
                )
            }
    }

    private static func dailySamples(from forecast: Forecast<DayWeather>) -> [DailyUV] {
        forecast.map {
            DailyUV(
                date: $0.date,
                maxUVIndex: Double($0.uvIndex.value),
                highTemperature: $0.highTemperature,
                lowTemperature: $0.lowTemperature,
                conditionSymbol: $0.symbolName,
                sunrise: $0.sun.sunrise,
                sunset: $0.sun.sunset
            )
        }
    }
}
