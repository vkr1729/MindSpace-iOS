import XCTest

final class MindSpaceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    @discardableResult
    private func launch(
        skipOnboarding: Bool = true,
        resetStore: Bool = true,
        scenario: String = "standard",
        accessibilityXXXL: Bool = false
    ) -> XCUIApplication {
        app.launchArguments = ["-ui-testing"]
        if resetStore {
            app.launchArguments.append("-reset-ui-testing")
        }
        if accessibilityXXXL {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
            ]
        }
        app.launchEnvironment["MINDSPACE_UI_TEST_SKIP_ONBOARDING"] = skipOnboarding ? "1" : "0"
        app.launchEnvironment["MINDSPACE_UI_TEST_SCENARIO"] = scenario
        app.launch()
        return app
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 12, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing UI element: \(element)", file: file, line: line)
    }

    private func tapWhenReady(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(element, file: file, line: line)
        if !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "UI element is not hittable: \(element)", file: file, line: line)
        element.tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFirstLaunchOnboardingAndTodayAtAccessibilityXXXL() {
        launch(skipOnboarding: false, accessibilityXXXL: true)

        waitFor(app.staticTexts["Welcome to MindSpace"])
        capture("01-Onboarding-Accessibility-XXXL")

        for _ in 0..<4 {
            tapWhenReady(app.buttons["onboarding.next"])
        }
        tapWhenReady(app.buttons["onboarding.disclaimer"])
        tapWhenReady(app.buttons["onboarding.finish"])

        let primaryAction = app.buttons["today.continue"]
        waitFor(primaryAction)
        XCTAssertTrue(primaryAction.isHittable, "The primary Today action must remain reachable at Accessibility XXXL")
        capture("02-Today-Accessibility-XXXL")
    }

    func testLibrarySearchCourseAndDeterministicAvailabilityStates() {
        launch(scenario: "library-states")
        tapWhenReady(app.buttons["tab.library"])

        waitFor(app.staticTexts["Library"])
        waitFor(app.staticTexts["Unavailable"])
        capture("03-Library-Availability-States")

        let search = app.textFields["library.search"]
        tapWhenReady(search)
        search.typeText("Basics")
        tapWhenReady(app.buttons["library.course.fixture_basics"])

        waitFor(app.staticTexts["Course progress"])
        waitFor(app.buttons["course.continue"])
        capture("04-Course-Progress")

        tapWhenReady(app.buttons["course.continue"])
        waitFor(app.descendants(matching: .any)["player.full"])
        capture("05-Player-From-Course")
    }

    func testPlaybackMiniPlayerCompletionAndProgressPersistence() {
        launch()
        tapWhenReady(app.buttons["today.continue"])

        let playPause = app.buttons["player.playPause"]
        waitFor(playPause)
        XCTAssertEqual(playPause.label, "Pause")
        playPause.tap()
        XCTAssertEqual(playPause.label, "Play")
        playPause.tap()

        tapWhenReady(app.buttons["Skip forward 15 seconds"])
        tapWhenReady(app.buttons["player.minimize"])
        waitFor(app.buttons["miniPlayer.open"])
        capture("06-Mini-Player")

        tapWhenReady(app.buttons["miniPlayer.open"])
        tapWhenReady(app.buttons["player.completeFixture"])
        waitFor(app.staticTexts["Practice complete"])
        capture("07-Completion")
        tapWhenReady(app.buttons["Feeling Centered"])
        tapWhenReady(app.buttons["completion.done"])

        tapWhenReady(app.buttons["player.minimize"])
        tapWhenReady(app.buttons["tab.progress"])
        waitFor(app.staticTexts["1 day streak"])
        capture("08-Updated-Progress")

        app.terminate()
        launch(resetStore: false)
        tapWhenReady(app.buttons["tab.progress"])
        waitFor(app.staticTexts["1 day streak"])
    }

    func testProgressDashboardSeedAndSettingsPortabilityAreReachable() {
        launch(scenario: "progress")
        tapWhenReady(app.buttons["tab.progress"])
        waitFor(app.staticTexts["3 day streak"])
        waitFor(app.staticTexts["Activity"])
        capture("09-Progress-Dashboard")

        tapWhenReady(app.buttons["tab.settings"])
        waitFor(app.staticTexts["Settings"])
        for _ in 0..<8 where !app.secureTextFields["settings.pat"].exists {
            app.swipeUp()
        }
        waitFor(app.secureTextFields["settings.pat"])
        XCTAssertEqual(app.secureTextFields["settings.pat"].value as? String, "ghp_... or github_pat_...")
        waitFor(app.staticTexts["Progress Backup & Portability"])
        capture("10-Settings-Private-Content")
    }
}
