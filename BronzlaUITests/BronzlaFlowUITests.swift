import XCTest

/// End-to-end coverage of the flows a first-time user actually walks.
///
/// The unit suites prove the maths and the state machine; nothing until now proved that the
/// buttons are wired to them. These tests exist to catch the class of bug where every
/// calculation is right and the screen still does nothing.
///
/// Runs against Turkish, the source language, because that is what the market sees and what
/// the layout must survive: Turkish strings run materially longer than their English
/// equivalents, so truncation shows up here first.
@MainActor
final class BronzlaFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiTestingFreshState", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
    }

    // MARK: - Onboarding

    func testQuizIsPresentedOnFirstLaunchAndCannotBeSkipped() {
        app.launch()

        let firstQuestion = app.staticTexts["Göz renginiz nedir?"]
        XCTAssertTrue(firstQuestion.waitForExistence(timeout: 10), "The quiz should block first launch")

        // The gate is a fullScreenCover with interactive dismissal disabled, so a downward
        // swipe must leave the user exactly where they were.
        app.swipeDown()
        XCTAssertTrue(firstQuestion.exists, "The quiz must not be dismissable by swiping")
    }

    func testCompletingTheQuizClassifiesAndReachesTheDashboard() {
        app.launch()
        XCTAssertTrue(app.staticTexts["Göz renginiz nedir?"].waitForExistence(timeout: 10))

        answerAllQuestions(choosingOptionAt: 2)

        // Seven middling answers score 14, which classifies as type III. That is the assertion
        // worth making: III and IV dominate this market, and it is why the instrument was
        // retuned for it.
        let result = app.staticTexts["Açık buğday"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), "Expected a type III result")

        app.buttons["Bu benim cilt tipim"].tap()

        XCTAssertTrue(app.tabBars.buttons["Bugün"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["UV"].waitForExistence(timeout: 15), "Dashboard should show a reading")
    }

    // MARK: - Navigation

    func testEveryTabOpensItsRealScreen() {
        launchPastOnboarding()

        let expectations: [(tab: String, title: String)] = [
            ("Tahmin", "Tahmin"),
            ("Takip", "Bronz Takipçi"),
            ("Ayarlar", "Ayarlar"),
            ("Bugün", "Bugün"),
        ]

        for (tab, title) in expectations {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(
                app.navigationBars[title].waitForExistence(timeout: 15),
                "The \(tab) tab should open its own screen"
            )
        }

        // The placeholder screens carried this copy. Its absence is what proves the real
        // features are wired in rather than the stubs they replaced.
        XCTAssertFalse(app.staticTexts["Seanslarınız ve ilerlemeniz."].exists)
    }

    // MARK: - Timer

    func testTimerStartsCountingAndCanBeCancelled() {
        launchPastOnboarding()
        app.tabBars.buttons["Zamanlayıcı"].tap()

        let start = app.buttons["Seansı başlat"]
        guard start.waitForExistence(timeout: 15) else {
            // Below the UV threshold there is deliberately no session to start. That is a
            // correct state, not a failure, so the test reports rather than asserts.
            XCTAssertTrue(app.staticTexts["Şu an güneşlenme zamanı değil"].exists)
            return
        }

        start.tap()

        let pause = app.buttons["Duraklat"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10), "A running session should offer a pause control")

        pause.tap()
        XCTAssertTrue(app.buttons["Devam et"].waitForExistence(timeout: 5), "Pausing should offer resume")

        app.buttons["Bitir"].tap()
        app.alerts.buttons["İptal et"].tap()

        XCTAssertTrue(start.waitForExistence(timeout: 10), "Cancelling should return to setup")
    }

    // MARK: - Settings

    func testDisclaimerAndPrivacyTextAreReachable() {
        launchPastOnboarding()
        app.tabBars.buttons["Ayarlar"].tap()

        app.buttons["Tıbbi uyarı"].tap()
        XCTAssertTrue(
            app.staticTexts["Bronzla tıbbi bir cihaz değildir ve tıbbi tavsiye vermez."].waitForExistence(timeout: 10),
            "The medical disclaimer must be reachable; App Review looks for it"
        )
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Gizlilik"].tap()
        XCTAssertTrue(app.staticTexts["Verileriniz cihazınızda kalır."].waitForExistence(timeout: 10))
    }

    // MARK: - Helpers

    private func answerAllQuestions(choosingOptionAt index: Int) {
        for question in 1...7 {
            let progress = app.staticTexts["Soru \(question) / 7"]
            XCTAssertTrue(progress.waitForExistence(timeout: 10), "Should reach question \(question)")

            let option = app.buttons["quiz.option.\(index)"]
            XCTAssertTrue(option.waitForExistence(timeout: 5), "Question \(question) should offer option \(index)")
            option.tap()
        }
    }

    private func launchPastOnboarding() {
        app.launch()
        if app.staticTexts["Göz renginiz nedir?"].waitForExistence(timeout: 10) {
            answerAllQuestions(choosingOptionAt: 2)
            let confirm = app.buttons["Bu benim cilt tipim"]
            XCTAssertTrue(confirm.waitForExistence(timeout: 10))
            confirm.tap()
        }
        XCTAssertTrue(app.tabBars.buttons["Bugün"].waitForExistence(timeout: 15))
    }
}
