#if DEBUG
import CoreLocation
import Foundation
import SwiftData

/// Deterministic demo content for App Store screenshots.
///
/// Activated only by the `-screenshotMode` launch argument, and only in DEBUG builds: this
/// whole file is compiled out of Release, so no shipping binary can be talked into serving
/// fabricated data by a launch argument. See `BronzlaApp` for the call sites.
enum ScreenshotSeed {
    /// True when the process was launched with `-screenshotMode`, resolved once per process.
    static let isActive = ProcessInfo.processInfo.arguments.contains("-screenshotMode")

    /// Fixed location shown throughout a screenshot run, so the capture never depends on the
    /// simulator having a simulated GPS route configured.
    static let place = LocationService.Place(
        coordinate: CLLocationCoordinate2D(latitude: 37.0344, longitude: 27.4305),
        name: "Bodrum, Muğla"
    )

    /// Points `service` at `place` so `DashboardView.refresh()` has a place to fetch for
    /// immediately, rather than waiting on a CoreLocation fix a screenshot run has no route to
    /// satisfy.
    @MainActor
    static func applyIfActive(to service: LocationService) {
        guard isActive else { return }
        service.manualPlace = place
    }

    // MARK: - Model container

    /// In-memory store seeded with a few weeks of believable history, so the tracker, streak
    /// calendar, Tan Score and family ranking screens all render real content instead of an
    /// empty first-run state.
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: UserProfile.self, TanSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let context = container.mainContext

        // Three profiles so "Family Ranking" (`FamilyBoardView`) has an actual ranking to show
        // rather than a single-entry list. "Ben" leads on a long, disciplined history; the other
        // two have shorter, more modest histories, which is what makes the ranking read as real
        // rather than staged.
        let ben = UserProfile(
            skinType: .iii,
            defaultSPF: 30,
            hasCompletedOnboarding: true,
            name: "Ben",
            isActive: true,
            colourHex: ProfilePalette.swatches[0]
        )
        let ayse = UserProfile(
            skinType: .ii,
            defaultSPF: 50,
            hasCompletedOnboarding: true,
            name: "Ayşe",
            colourHex: ProfilePalette.swatches[1]
        )
        let deniz = UserProfile(
            skinType: .iv,
            defaultSPF: 20,
            hasCompletedOnboarding: true,
            name: "Deniz",
            colourHex: ProfilePalette.swatches[3]
        )
        [ben, ayse, deniz].forEach(context.insert)

        for session in demoSessions(profile: ben, specs: benSpecs) {
            context.insert(session)
        }
        for session in demoSessions(profile: ayse, specs: ayseSpecs) {
            context.insert(session)
        }
        for session in demoSessions(profile: deniz, specs: denizSpecs) {
            context.insert(session)
        }

        try context.save()
        return container
    }

    // MARK: - Sessions

    /// One entry per logged session. Hour and minute are ignored for `dayOffset == 0`, since
    /// today's session is instead anchored just behind the actual capture time so it can never
    /// land in the future.
    private struct SessionSpec {
        let dayOffset: Int
        let hour: Int
        let minute: Int
        let durationMinutes: Int
        let spf: Int
        let uvIndex: Double
    }

    /// Two consecutive-day blocks: an eight-day run in the past, which becomes the longest
    /// streak, and a five-day run ending today, which becomes the current streak. A gap of
    /// several days separates them so the two figures read distinctly. A handful of days carry
    /// a second session (morning and evening) so the total sits at 16, inside the 12 to 18
    /// range asked for, without changing either streak, which counts distinct calendar days.
    /// Every combination here keeps `burnRisk` well under 1.0: this profile has never burned.
    private static let benSpecs: [SessionSpec] = [
        // Longest streak: eight consecutive days.
        SessionSpec(dayOffset: -20, hour: 10, minute: 15, durationMinutes: 35, spf: 30, uvIndex: 7),
        SessionSpec(dayOffset: -19, hour: 9, minute: 45, durationMinutes: 50, spf: 20, uvIndex: 6),
        SessionSpec(dayOffset: -18, hour: 11, minute: 0, durationMinutes: 25, spf: 50, uvIndex: 8),
        SessionSpec(dayOffset: -18, hour: 16, minute: 30, durationMinutes: 40, spf: 30, uvIndex: 5),
        SessionSpec(dayOffset: -17, hour: 10, minute: 30, durationMinutes: 60, spf: 15, uvIndex: 6),
        SessionSpec(dayOffset: -16, hour: 9, minute: 30, durationMinutes: 45, spf: 30, uvIndex: 7),
        SessionSpec(dayOffset: -16, hour: 17, minute: 0, durationMinutes: 30, spf: 20, uvIndex: 4),
        SessionSpec(dayOffset: -15, hour: 10, minute: 0, durationMinutes: 55, spf: 30, uvIndex: 8),
        SessionSpec(dayOffset: -14, hour: 11, minute: 15, durationMinutes: 20, spf: 50, uvIndex: 7),
        SessionSpec(dayOffset: -13, hour: 10, minute: 45, durationMinutes: 40, spf: 30, uvIndex: 6),
        // Current streak: five consecutive days, the last of which is today.
        SessionSpec(dayOffset: -4, hour: 10, minute: 0, durationMinutes: 45, spf: 30, uvIndex: 7),
        SessionSpec(dayOffset: -3, hour: 9, minute: 30, durationMinutes: 35, spf: 20, uvIndex: 6),
        SessionSpec(dayOffset: -2, hour: 11, minute: 0, durationMinutes: 30, spf: 30, uvIndex: 8),
        SessionSpec(dayOffset: -2, hour: 16, minute: 45, durationMinutes: 25, spf: 15, uvIndex: 4),
        SessionSpec(dayOffset: -1, hour: 10, minute: 15, durationMinutes: 50, spf: 50, uvIndex: 7),
        SessionSpec(dayOffset: 0, hour: 10, minute: 0, durationMinutes: 30, spf: 30, uvIndex: 6),
    ]

    /// A shorter, less consistent history, so the ranking places second rather than tying.
    private static let ayseSpecs: [SessionSpec] = [
        SessionSpec(dayOffset: -12, hour: 11, minute: 0, durationMinutes: 25, spf: 50, uvIndex: 6),
        SessionSpec(dayOffset: -9, hour: 10, minute: 30, durationMinutes: 30, spf: 50, uvIndex: 7),
        SessionSpec(dayOffset: -8, hour: 9, minute: 45, durationMinutes: 20, spf: 30, uvIndex: 5),
        SessionSpec(dayOffset: -5, hour: 11, minute: 15, durationMinutes: 35, spf: 50, uvIndex: 8),
        SessionSpec(dayOffset: -3, hour: 10, minute: 0, durationMinutes: 25, spf: 30, uvIndex: 6),
        SessionSpec(dayOffset: -1, hour: 10, minute: 30, durationMinutes: 30, spf: 50, uvIndex: 7),
    ]

    /// Fewer sessions still, so the ranking places third. Still entirely clean: this is a
    /// screenshot of a sun-safety app, and nobody in the seeded household has ever burned.
    private static let denizSpecs: [SessionSpec] = [
        SessionSpec(dayOffset: -11, hour: 12, minute: 0, durationMinutes: 40, spf: 20, uvIndex: 7),
        SessionSpec(dayOffset: -7, hour: 11, minute: 30, durationMinutes: 45, spf: 20, uvIndex: 8),
        SessionSpec(dayOffset: -6, hour: 10, minute: 45, durationMinutes: 30, spf: 15, uvIndex: 6),
        SessionSpec(dayOffset: -2, hour: 11, minute: 0, durationMinutes: 35, spf: 20, uvIndex: 7),
    ]

    private static func demoSessions(
        profile: UserProfile,
        specs: [SessionSpec],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [TanSession] {
        let today = calendar.startOfDay(for: referenceDate)

        return specs.map { spec in
            let day = calendar.date(byAdding: .day, value: spec.dayOffset, to: today) ?? today
            let duration = TimeInterval(spec.durationMinutes * 60)

            let startedAt: Date
            if spec.dayOffset == 0 {
                // Whatever time of day a screenshot run happens to start, today's session must
                // already be in the past, and must stay on today's calendar day.
                let latestPossibleStart = referenceDate.addingTimeInterval(-duration - 60)
                startedAt = max(day, latestPossibleStart)
            } else {
                startedAt = calendar.date(bySettingHour: spec.hour, minute: spec.minute, second: 0, of: day) ?? day
            }

            let dose = ExposureCalculator.dose(uvIndex: spec.uvIndex, over: .seconds(duration), spf: spec.spf)

            return TanSession(
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(duration),
                placeName: place.name,
                spf: spec.spf,
                skinType: profile.skinType,
                erythemalDose: dose,
                peakUVIndex: spec.uvIndex,
                profile: profile
            )
        }
    }
}

/// Fixed, high-but-safe UV reading for screenshot captures.
///
/// Wraps `SampleUVProvider` rather than re-deriving the diurnal curve, then overrides only what
/// a screenshot needs to be stable: the current index pinned to 8 regardless of capture time,
/// and the source marked `.live` so `DashboardView` never shows its "sample data" banner or a
/// staleness notice.
struct ScreenshotUVProvider: UVDataProviding {
    private let underlying = SampleUVProvider(
        peakUVIndex: 8,
        peakTemperature: 33,
        placeNameOverride: ScreenshotSeed.place.name
    )

    func report(for coordinate: CLLocationCoordinate2D, placeName: String) async throws -> UVReport {
        let sample = try await underlying.report(for: coordinate, placeName: placeName)

        let current = UVSnapshot(
            uvIndex: 8,
            temperature: sample.current.temperature,
            conditionSymbol: "sun.max.fill",
            isDaylight: true,
            sunrise: sample.current.sunrise,
            sunset: sample.current.sunset,
            observedAt: .now
        )

        return UVReport(
            placeName: sample.placeName,
            current: current,
            hourly: sample.hourly,
            daily: sample.daily,
            source: .live,
            fetchedAt: .now
        )
    }
}
#endif
