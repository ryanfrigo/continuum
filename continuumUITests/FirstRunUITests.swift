import XCTest

/// A new user's first minute: onboarding, one habit, one hold. It needs a
/// fresh install, so it has its own plan and CI's unit plan leaves it out:
///   xcrun simctl uninstall $SIM orion-labs.continuum
///   xcodebuild test -scheme continuum -testPlan FirstRun -destination …
final class FirstRunUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testNewUserCanMarkFirstHabitDone() throws {
        let app = XCUIApplication()
        app.launch()

        // Onboarding: four pages, then pick a habit
        for _ in 0..<4 {
            let next = app.buttons["Continue"]
            XCTAssertTrue(next.waitForExistence(timeout: 10))
            next.tap()
        }
        let pick = app.buttons["Read 30 Pages"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["Get Started"].tap()
        snap(app, "1-after-onboarding")

        // Walkthrough, then the reminder prompt if it shows
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }
        snap(app, "2-after-walkthrough")
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 3) { notNow.tap() }

        // Hold the card
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Read 30 Pages")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), app.debugDescription)
        snap(app, "3-before-hold")
        card.press(forDuration: 1.6)
        sleep(2)
        snap(app, "4-after-hold")

        let today = app.staticTexts["1/1"]
        XCTAssertTrue(today.waitForExistence(timeout: 5), "TODAY did not reach 1/1\n\(app.debugDescription)")
    }
}
