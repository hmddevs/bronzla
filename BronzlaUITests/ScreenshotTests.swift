import XCTest

/// Captures the App Store screenshot set for both locales the store listing needs.
///
/// Runs against `-screenshotMode`, which seeds three profiles, a realistic session history and
/// a pinned live UV 8 reading (see `ScreenshotSeed`), so every screen renders real content
/// rather than an empty first-run state, a sample-data banner or an offline notice. Navigation
/// is by tab index and accessibility identifier rather than localised text, because this test
/// runs the same walk twice: once in English, once in Turkish.
@MainActor
final class ScreenshotTests: XCTestCase {

    private struct LocaleRun {
        let directoryName: String
        let launchArguments: [String]
    }

    private static let runs: [LocaleRun] = [
        LocaleRun(
            directoryName: "en",
            launchArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        ),
        LocaleRun(
            directoryName: "tr",
            launchArguments: ["-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        ),
    ]

    private static let outputRoot = URL(
        fileURLWithPath: "/Users/umutguden/Desktop/TanApp/build/screenshots"
    )

    func testCapturesAppStoreScreenshotsInBothLocales() throws {
        for run in Self.runs {
            try captureScreenshots(for: run)
        }
    }

    // MARK: - Walk

    private func captureScreenshots(for run: LocaleRun) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-screenshotMode"] + run.launchArguments
        app.launch()

        let directory = Self.outputRoot.appendingPathComponent(run.directoryName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 01: Dashboard, showing the pinned live UV reading.
        let uvGauge = element("dashboard.uvGauge", in: app)
        XCTAssertTrue(uvGauge.waitForExistence(timeout: 20), "Dashboard should show a UV reading")
        capture("01-dashboard", in: directory)

        // 02: Safe-exposure card and advice, reached by scrolling the same dashboard.
        let safeExposureCard = element("dashboard.safeExposureCard", in: app)
        scrollUntilVisible(safeExposureCard, in: app)
        XCTAssertTrue(safeExposureCard.exists, "Scrolling should bring the safe-exposure card into frame")
        capture("02-exposure", in: directory)

        // 03: Timer.
        app.tabBars.buttons.element(boundBy: 2).tap()
        let timerSetup = element("timer.setup", in: app)
        XCTAssertTrue(timerSetup.waitForExistence(timeout: 20), "Timer should reach its setup screen")
        capture("03-timer", in: directory)

        // 04: UV forecast chart.
        app.tabBars.buttons.element(boundBy: 1).tap()
        let forecastChart = element("forecast.chart", in: app)
        XCTAssertTrue(forecastChart.waitForExistence(timeout: 20), "Forecast should render its chart")
        capture("04-forecast", in: directory)

        // 05: Tan tracker calendar and streak.
        app.tabBars.buttons.element(boundBy: 3).tap()
        let streakCalendar = element("tracker.streakCalendar", in: app)
        XCTAssertTrue(streakCalendar.waitForExistence(timeout: 20), "Tracker should show the streak calendar")
        capture("05-tracker", in: directory)

        // 06: Tan Score / family ranking, reached via Settings > Profiles > Family Ranking.
        app.tabBars.buttons.element(boundBy: 4).tap()
        let profilesLink = element("settings.profiles", in: app)
        XCTAssertTrue(profilesLink.waitForExistence(timeout: 15), "Settings should offer a way to Profiles")
        profilesLink.tap()

        let familyRankingLink = element("profiles.familyRanking", in: app)
        XCTAssertTrue(
            familyRankingLink.waitForExistence(timeout: 15),
            "Three seeded profiles should surface the Family Ranking link"
        )
        familyRankingLink.tap()

        let familyBoard = element("social.familyBoard", in: app)
        XCTAssertTrue(familyBoard.waitForExistence(timeout: 15), "The family ranking list should load")
        capture("06-score", in: directory)

        app.terminate()
    }

    // MARK: - Helpers

    /// Looks up a custom identifier regardless of the element type SwiftUI happened to render it
    /// as, since a `List`, a `NavigationLink` row and a plain view all surface differently.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Swipes the frontmost scroll view up until `target` is on screen, or gives up after
    /// `maxSwipes`, so a layout change can never spin this into an infinite loop.
    private func scrollUntilVisible(_ target: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var attempts = 0
        while !(target.exists && target.isHittable), attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    private func capture(_ name: String, in directory: URL) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = directory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("Failed to write screenshot \(name) to \(url.path): \(error)")
        }
    }
}
