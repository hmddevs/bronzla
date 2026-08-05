import Foundation
import Testing
@testable import Bronzla

/// Peak-window derivation: the contiguous stretch of hours at or above UV 8, phrased for a
/// sunbather deciding when to stay in the shade.
@Suite("Forecast peak window")
struct ForecastTests {

    // Fixed calendar and timezone so hour labels never depend on the machine running the test.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    // Resolved through the catalogue rather than written out, for the same reason the calendar
    // above is pinned: the assertion is about which hours are picked, not which language the
    // machine running the test happens to be in.
    private func peakWindow(_ start: String, _ end: String) -> String {
        String(localized: "Highest risk hours: \(start) - \(end)")
    }

    private func hour(_ hour: Int, uvIndex: Double, on day: Int = 1) -> HourlyUV {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = day
        components.hour = hour
        let date = calendar.date(from: components)!
        return HourlyUV(date: date, uvIndex: uvIndex, temperature: Measurement(value: 30, unit: .celsius), isDaylight: true)
    }

    @Test("Reports the contiguous window where UV reaches very high")
    func reportsContiguousWindow() {
        let hours = [
            hour(9, uvIndex: 6),
            hour(10, uvIndex: 7.5),
            hour(11, uvIndex: 8),
            hour(12, uvIndex: 9.5),
            hour(13, uvIndex: 10),
            hour(14, uvIndex: 9),
            hour(15, uvIndex: 8),
            hour(16, uvIndex: 7),
            hour(17, uvIndex: 5),
        ]

        let summary = ForecastView.peakWindowSummary(for: hours, calendar: calendar)

        #expect(summary == peakWindow("11.00", "16.00"))
    }

    @Test("Says nothing risky when no hour reaches the threshold")
    func noRiskyHours() {
        let hours = [hour(9, uvIndex: 3), hour(12, uvIndex: 6.9), hour(15, uvIndex: 4)]

        let summary = ForecastView.peakWindowSummary(for: hours, calendar: calendar)

        #expect(summary == "No extreme risk hours today")
    }

    @Test("Picks the longer of two separate risky windows")
    func picksLongestRun() {
        let hours = [
            hour(8, uvIndex: 8),
            hour(9, uvIndex: 5),
            hour(12, uvIndex: 8),
            hour(13, uvIndex: 9),
            hour(14, uvIndex: 8),
            hour(15, uvIndex: 5),
        ]

        let summary = ForecastView.peakWindowSummary(for: hours, calendar: calendar)

        #expect(summary == peakWindow("12.00", "15.00"))
    }

    @Test("An empty hourly feed yields the no-risk message")
    func emptyFeed() {
        let summary = ForecastView.peakWindowSummary(for: [], calendar: calendar)

        #expect(summary == "No extreme risk hours today")
    }
}
