import CoreLocation
import Foundation

/// Deterministic stand-in for WeatherKit, used by SwiftUI previews, unit tests and unsigned
/// simulator builds where the WeatherKit entitlement is unavailable.
///
/// The curve is modelled rather than random so previews are stable across redraws and a
/// screenshot taken today looks like a screenshot taken tomorrow.
struct SampleUVProvider: UVDataProviding {
    /// Peak UV index at solar noon. 9 is a realistic July figure for the Turkish coast.
    var peakUVIndex: Double = 9
    var peakTemperature: Double = 32
    var placeNameOverride: String?
    /// Set to have the provider throw, so error states can be designed without unplugging.
    var failure: UVDataError?

    func report(for coordinate: CLLocationCoordinate2D, placeName: String) async throws -> UVReport {
        if let failure { throw failure }

        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)

        let hourly = (0..<48).map { offset -> HourlyUV in
            let date = calendar.date(byAdding: .hour, value: offset, to: startOfToday) ?? startOfToday
            let uv = Self.modelledUVIndex(at: date, peak: peakUVIndex, calendar: calendar)
            return HourlyUV(
                date: date,
                uvIndex: uv,
                temperature: Measurement(value: Self.modelledTemperature(at: date, peak: peakTemperature, calendar: calendar), unit: .celsius),
                isDaylight: uv > 0
            )
        }

        let daily = (0..<10).map { offset -> DailyUV in
            let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
            // Gentle variation so the forecast chart is not a flat line.
            let drift = 1 - Double(offset % 4) * 0.08
            return DailyUV(
                date: date,
                maxUVIndex: (peakUVIndex * drift).rounded(),
                highTemperature: Measurement(value: peakTemperature * drift, unit: .celsius),
                lowTemperature: Measurement(value: peakTemperature * drift - 9, unit: .celsius),
                conditionSymbol: offset % 4 == 2 ? "cloud.sun.fill" : "sun.max.fill",
                sunrise: calendar.date(bySettingHour: 6, minute: 5, second: 0, of: date),
                sunset: calendar.date(bySettingHour: 20, minute: 20, second: 0, of: date)
            )
        }

        let currentUV = Self.modelledUVIndex(at: now, peak: peakUVIndex, calendar: calendar)

        return UVReport(
            placeName: placeNameOverride ?? placeName,
            current: UVSnapshot(
                uvIndex: currentUV,
                temperature: Measurement(value: Self.modelledTemperature(at: now, peak: peakTemperature, calendar: calendar), unit: .celsius),
                conditionSymbol: currentUV > 0 ? "sun.max.fill" : "moon.stars.fill",
                isDaylight: currentUV > 0,
                sunrise: daily.first?.sunrise,
                sunset: daily.first?.sunset,
                observedAt: now
            ),
            hourly: hourly,
            daily: daily,
            source: .sample,
            fetchedAt: now
        )
    }

    // MARK: - Model

    /// Half-sine between sunrise and sunset, squared to sharpen the midday peak the way real
    /// UV behaves. Zero outside daylight.
    private static func modelledUVIndex(at date: Date, peak: Double, calendar: Calendar) -> Double {
        let hour = fractionalHour(of: date, calendar: calendar)
        let sunrise = 6.0, sunset = 20.0
        guard hour > sunrise, hour < sunset else { return 0 }

        let progress = (hour - sunrise) / (sunset - sunrise)
        let elevation = sin(progress * .pi)
        return (peak * pow(elevation, 2)).rounded()
    }

    /// Temperature lags the sun by roughly three hours, which is why the hottest part of a
    /// Turkish afternoon is 16.00 while the UV peak has already passed.
    private static func modelledTemperature(at date: Date, peak: Double, calendar: Calendar) -> Double {
        let hour = fractionalHour(of: date, calendar: calendar)
        let shifted = (hour - 16 + 24).truncatingRemainder(dividingBy: 24)
        return peak - 9 * (1 - cos(shifted / 24 * 2 * .pi)) / 2
    }

    private static func fractionalHour(of date: Date, calendar: Calendar) -> Double {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
    }
}

extension UVReport {
    /// Convenience for previews. Synchronous because previews cannot await.
    static func preview(peakUVIndex: Double = 9, placeName: String = "Antalya") -> UVReport {
        let calendar = Calendar.current
        let now = Date.now
        return UVReport(
            placeName: placeName,
            current: UVSnapshot(
                uvIndex: peakUVIndex,
                temperature: Measurement(value: 32, unit: .celsius),
                conditionSymbol: "sun.max.fill",
                isDaylight: true,
                sunrise: calendar.date(bySettingHour: 6, minute: 5, second: 0, of: now),
                sunset: calendar.date(bySettingHour: 20, minute: 20, second: 0, of: now),
                observedAt: now
            ),
            hourly: [],
            daily: [],
            source: .sample,
            fetchedAt: now
        )
    }
}
