import XCTest

final class NavigationTests: XCTestCase {
    func testFinalWorkspaceIsExplicitDemo() {
        let app = XCUIApplication()
        app.launchArguments = ["-analysisMode", "mock"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Explore the final UI demo"].tap()
        XCTAssertTrue(app.navigationBars["Demo workspace"].waitForExistence(timeout: 5))
    }
    func testLiveMockResponseDisclosure() async throws {
        // Opt-in local integration: run the existing mock backend on loopback port 3101.
        let health = URL(string: "http://127.0.0.1:3101/health")!
        var request = URLRequest(url: health)
        request.timeoutInterval = 2
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw XCTSkip("Start the existing mock backend on 127.0.0.1:3101 for this integration test")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-analysisMode", "live", "-developmentAPIBaseURL", "http://127.0.0.1:3101"]
        app.launch()
        app.tabBars.buttons["Analyze"].tap()
        app.buttons["sampleMenu"].tap()
        app.buttons["The urgent bank call"].tap()
        app.swipeUp()
        app.buttons["submitAnalysis"].tap()
        let warning = app.staticTexts["liveReturnedMock"]
        for _ in 0..<6 where !warning.isHittable { app.swipeUp() }
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["demoBanner"].exists)
        XCTAssertFalse(app.staticTexts["Analyzed with NVIDIA"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Module 1 live mock disclosure"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFourTabsAndDemoDisclosure() {
        let app = XCUIApplication()
        app.launchArguments = ["-analysisMode", "mock", "-developmentAPIBaseURL", ""]
        app.launch()
        XCTAssertTrue(app.navigationBars["kavach"].waitForExistence(timeout: 5))
        app.buttons["Explore a sample"].tap()
        XCTAssertTrue(app.navigationBars["Analyze"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["analysisContent"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["submitAnalysis"].isEnabled)
        app.buttons["sampleMenu"].tap()
        app.buttons["The urgent bank call"].tap()
        app.swipeUp()
        app.buttons["submitAnalysis"].tap()
        app.swipeUp()
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

    func testDarkLargeTextLiveSetupError() {
        let app = XCUIApplication()
        app.launchArguments = ["-analysisMode", "live", "-developmentAPIBaseURL", "",
                               "-AppleInterfaceStyle", "Dark",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Analyze"].tap()
        let sample = app.buttons["sampleMenu"]
        for _ in 0..<8 where !sample.isHittable { app.swipeUp() }
        XCTAssertTrue(sample.isHittable)
        sample.tap()
        app.buttons["The urgent bank call"].tap()
        let submit = app.buttons["submitAnalysis"]
        for _ in 0..<8 where !submit.isHittable { app.swipeUp() }
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        let guidance = app.staticTexts["Add your backend address in Settings before using Live backend."]
        for _ in 0..<8 where !guidance.isHittable { app.swipeUp() }
        XCTAssertTrue(guidance.exists)
        XCTAssertFalse(app.staticTexts["Analyzed with NVIDIA"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Module 1 dark large text setup error"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
