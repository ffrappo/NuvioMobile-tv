import XCTest

final class NuvioTVNavigationUITests: XCTestCase {
    private let remote = XCUIRemote.shared

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRootTabsExposeNativeSidebarItems() throws {
        let app = launchGuestApp()
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 15))
        remote.press(.left)
        for label in ["Home", "Discover", "Search", "Library", "Addons", "Settings"] {
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5))
        }
        attachScreenshot(name: "root-sidebar-items")
    }

    func testHomeDetailsRoundTripPreservesNavigation() throws {
        let app = launchGuestApp()
        XCTAssertTrue(featuredButton(in: app).waitForExistence(timeout: 20))
        remote.press(.select)
        XCTAssertTrue(app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
            "Library", "Remove"
        )).firstMatch.waitForExistence(timeout: 15))
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 10))
    }

    func testExpandedSidebarLeavesHeroReadable() throws {
        let app = launchGuestApp()
        let heroButton = featuredButton(in: app)
        XCTAssertTrue(heroButton.waitForExistence(timeout: 20))
        remote.press(.left)
        XCTAssertTrue(app.staticTexts["Discover"].waitForExistence(timeout: 5))
        XCTAssertTrue(heroButton.exists)
        XCTAssertGreaterThan(heroButton.frame.minX, 300)
        attachScreenshot(name: "home-expanded-sidebar")
    }

    func testHomeRestoresFocusAfterDetailsRoundTrip() throws {
        let app = launchGuestApp()
        let heroButton = featuredButton(in: app)
        XCTAssertTrue(heroButton.waitForExistence(timeout: 20))
        remote.press(.down)
        remote.press(.down)
        sleep(1)
        let focusedBefore = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == YES")).firstMatch
        XCTAssertTrue(focusedBefore.waitForExistence(timeout: 5))
        let labelBefore = focusedBefore.label
        remote.press(.select)
        XCTAssertTrue(app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
            "Library", "Remove"
        )).firstMatch.waitForExistence(timeout: 15))
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 10))
        sleep(1)
        let focusedAfter = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == YES")).firstMatch
        XCTAssertTrue(focusedAfter.waitForExistence(timeout: 5))
        XCTAssertEqual(focusedAfter.label, labelBefore)
    }

    private func featuredButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH[c] %@", "featured")).firstMatch
    }

    private func launchGuestApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-nuvio.tv.continueAsGuest.v1", "YES"]
        app.launch()
        return app
    }


    private func attachScreenshot(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
