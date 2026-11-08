import XCTest

final class NavigationTests: XCTestCase {
    func testFourTabsAndDemoDisclosure() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["kavach"].waitForExistence(timeout: 5))
        app.buttons["Explore a sample"].tap()
        XCTAssertTrue(app.navigationBars["Analyze"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["demoBanner"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Circle"].tap()
        XCTAssertTrue(app.staticTexts["PREVIEW · No circle is connected"].exists)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Demo Mode · On"].exists)
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["kavach"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Kavach Home"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
