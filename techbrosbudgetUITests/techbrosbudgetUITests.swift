//
//  techbrosbudgetUITests.swift
//  techbrosbudgetUITests
//
//  Created by Reda Boutayeb on 6/14/26.
//

import XCTest

final class techbrosbudgetUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeSurfacesRemainReadableWithPreviewData() throws {
        let app = makePreviewApp()
        app.launch()

        XCTAssertTrue(app.buttons["Tech Bros logo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Tech Bro"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["Close"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["Tech Bros logo"].isHittable)
        XCTAssertTrue(app.staticTexts["Month"].exists)
        XCTAssertTrue(app.staticTexts["Week"].exists)
        XCTAssertTrue(app.staticTexts["Today"].exists)
        XCTAssertTrue(app.staticTexts["Categories"].exists)
        XCTAssertTrue(app.staticTexts["Recent"].exists)
        XCTAssertTrue(app.buttons["Add expense"].isHittable)
        XCTAssertTrue(app.buttons["Settings"].isHittable)

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Apple Intelligence"].exists)
        XCTAssertTrue(app.buttons["Done"].isHittable)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Readable home and settings surfaces"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOnboardingWelcomesNewUsersAndContinuesToHome() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_SHOW_ONBOARDING")
        app.launch()

        XCTAssertTrue(app.images["Tech Bros logo"].waitForExistence(timeout: 5))
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.isHittable)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Onboarding screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        continueButton.tap()

        XCTAssertTrue(app.staticTexts["Month"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add expense"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Tech Bro"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["Close"].waitForExistence(timeout: 1))
        XCTAssertFalse(continueButton.exists)
    }

    @MainActor
    func testBudgetChatRendersAssistantMarkdown() throws {
        let app = makePreviewApp()
        app.launchArguments.append("UITEST_MARKDOWN_CHAT")
        app.launch()

        XCTAssertTrue(app.buttons["Tech Bros logo"].waitForExistence(timeout: 5))
        openBudgetChat(in: app)

        XCTAssertTrue(app.staticTexts["Tech Bro"].waitForExistence(timeout: 5))
        let renderedMarkdown = app.staticTexts.containing(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@ AND label CONTAINS %@",
            "bold spending",
            "friendly tone",
            "daily spent"
        )).firstMatch
        XCTAssertTrue(renderedMarkdown.waitForExistence(timeout: 5))

        let rawMarkdown = app.staticTexts.containing(NSPredicate(
            format: "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@",
            "**bold spending**",
            "*friendly tone*",
            "`daily spent`"
        )).firstMatch
        XCTAssertFalse(rawMarkdown.exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Budget chat rendered markdown"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makePreviewApp().launch()
        }
    }

    private func makePreviewApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_PREVIEW_DATA")
        return app
    }

    private func openBudgetChat(in app: XCUIApplication) {
        if app.staticTexts["Tech Bro"].waitForExistence(timeout: 1) {
            return
        }

        for _ in 0..<5 where !app.staticTexts["Pull to chat"].exists {
            app.swipeUp()
        }

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))

        for _ in 0..<3 where !app.staticTexts["Tech Bro"].exists {
            start.press(forDuration: 0.05, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}
