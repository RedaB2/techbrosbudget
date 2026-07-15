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
        // Categories moved off the home screen into the period detail view.
        XCTAssertFalse(app.staticTexts["Categories"].exists)
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
    func testOnboardingWelcomesNewUsersThenOffersAutoCapture() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_SHOW_ONBOARDING", "UITEST_SHOW_AUTOCAPTURE_INTRO"]
        app.launch()

        XCTAssertTrue(app.images["Tech Bros logo"].waitForExistence(timeout: 5))
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.isHittable)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Onboarding screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        continueButton.tap()

        // The auto-capture intro babysits new users right after the welcome
        // screen; declining it lands on the home screen.
        let setItUp = app.buttons["AutoCaptureSetItUp"]
        XCTAssertTrue(setItUp.waitForExistence(timeout: 8))

        let introAttachment = XCTAttachment(screenshot: app.screenshot())
        introAttachment.name = "Auto-capture intro after onboarding"
        introAttachment.lifetime = .keepAlways
        add(introAttachment)

        app.buttons["AutoCaptureMaybeLater"].tap()

        XCTAssertTrue(app.staticTexts["Month"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add expense"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Tech Bro"].waitForExistence(timeout: 1))
        XCTAssertFalse(continueButton.exists)
    }

    @MainActor
    func testAutoCaptureIntroWalksThroughSetup() throws {
        let app = makePreviewApp()
        app.launchArguments.append("UITEST_SHOW_AUTOCAPTURE_INTRO")
        app.launch()

        // The pitch pops on its own shortly after launch.
        let setItUp = app.buttons["AutoCaptureSetItUp"]
        XCTAssertTrue(setItUp.waitForExistence(timeout: 8))

        let pitchAttachment = XCTAttachment(screenshot: app.screenshot())
        pitchAttachment.name = "Auto-capture pitch"
        pitchAttachment.lifetime = .keepAlways
        add(pitchAttachment)

        setItUp.tap()

        // Guided steps: exact Shortcuts labels are shown as chips.
        XCTAssertTrue(app.buttons["AutoCaptureOpenShortcuts"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Transaction"].exists)
        XCTAssertTrue(app.staticTexts["Run Immediately"].exists)
        XCTAssertTrue(app.staticTexts["Log Wallet Transaction"].exists)

        let stepsAttachment = XCTAttachment(screenshot: app.screenshot())
        stepsAttachment.name = "Auto-capture guided steps"
        stepsAttachment.lifetime = .keepAlways
        add(stepsAttachment)

        app.buttons["AutoCaptureStepsDone"].tap()

        let done = app.buttons["AutoCaptureDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))

        let finishAttachment = XCTAttachment(screenshot: app.screenshot())
        finishAttachment.name = "Auto-capture finish"
        finishAttachment.lifetime = .keepAlways
        add(finishAttachment)

        done.tap()

        XCTAssertTrue(app.buttons["Add expense"].waitForExistence(timeout: 5))

        // Settings now shows the slim status row with a single setup button.
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Auto-Capture"].exists)
        XCTAssertTrue(app.buttons["AutoCaptureSettingsSetup"].exists)
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
    func testAddExpenseSavesThroughSingleMonolithButton() throws {
        let app = makePreviewApp()
        app.launch()

        XCTAssertTrue(app.buttons["Add expense"].waitForExistence(timeout: 5))
        app.buttons["Add expense"].tap()

        let amountField = app.textFields["Amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))

        // The redundant native toolbar buttons are gone; swipe-down closes,
        // and the Monolith block button is the only way to save.
        XCTAssertFalse(app.navigationBars.buttons["Add"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Cancel"].exists)

        amountField.tap()
        amountField.typeText("4.50")

        // Expand the sheet so the save button is on screen.
        app.swipeUp()

        let saveButton = app.buttons["SaveExpenseButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))

        // The simulator keyboard occasionally drops keys; make sure at least
        // one digit landed so the button is enabled before saving.
        if !saveButton.isEnabled {
            amountField.tap()
            amountField.typeText("2")
            app.swipeUp()
        }

        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        // Sheet dismisses and the new note-less expense shows up in Recent.
        XCTAssertTrue(app.staticTexts["Expense"].waitForExistence(timeout: 5))
        XCTAssertFalse(amountField.exists)
    }

    @MainActor
    func testSwipeToDeleteRemovesRecentExpense() throws {
        let app = makePreviewApp()
        app.launch()

        let row = app.staticTexts["Lyft back from office"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // The delete action stays out of the accessibility tree until revealed.
        XCTAssertFalse(app.buttons["Delete expense"].exists)

        row.swipeLeft()

        let deleteButton = app.buttons["Delete expense"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Swipe to delete revealed"
        attachment.lifetime = .keepAlways
        add(attachment)

        deleteButton.tap()

        XCTAssertFalse(row.waitForExistence(timeout: 2))
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

        let chatButton = app.buttons["Budget Chat"]
        for _ in 0..<3 where !app.staticTexts["Tech Bro"].exists {
            chatButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}
