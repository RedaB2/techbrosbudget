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

        // First the ready-made shortcut is offered for one-tap import.
        XCTAssertTrue(app.buttons["AutoCaptureAddShortcut"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Log My Purchase"].exists)

        let addAttachment = XCTAttachment(screenshot: app.screenshot())
        addAttachment.name = "Auto-capture add shortcut"
        addAttachment.lifetime = .keepAlways
        add(addAttachment)

        app.buttons["AutoCaptureContinueToSteps"].tap()

        // Guided steps: exact Shortcuts labels are shown as chips.
        XCTAssertTrue(app.buttons["AutoCaptureOpenShortcuts"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Automation"].exists)
        XCTAssertTrue(app.staticTexts["Wallet"].exists)
        XCTAssertTrue(app.staticTexts["Run Immediately"].exists)
        XCTAssertTrue(app.staticTexts["Log My Purchase"].exists)

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

    /// End-to-end proof that the bundled signed shortcut really imports into
    /// the Shortcuts app. Drives system UI and another app, so it's opt-in:
    /// run with TEST_RUNNER_RUN_CROSSAPP_TESTS=1.
    @MainActor
    func testAddShortcutImportsIntoShortcutsApp() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_CROSSAPP_TESTS"] == "1",
            "Cross-app test; set RUN_CROSSAPP_TESTS=1 to run."
        )

        let app = makePreviewApp()
        app.launchArguments.append("UITEST_SHOW_AUTOCAPTURE_INTRO")
        app.launch()

        let setItUp = app.buttons["AutoCaptureSetItUp"]
        XCTAssertTrue(setItUp.waitForExistence(timeout: 8))
        setItUp.tap()

        let addShortcut = app.buttons["AutoCaptureAddShortcut"]
        XCTAssertTrue(addShortcut.waitForExistence(timeout: 3))
        addShortcut.tap()

        // The open-in sheet lists apps able to import the file; pick Shortcuts.
        // The sheet is a remote view, so tap by screen coordinates — element
        // taps frequently don't land across the process boundary.
        let shortcutsTarget = app.cells["Shortcuts"].firstMatch
        XCTAssertTrue(shortcutsTarget.waitForExistence(timeout: 8), "Share sheet did not offer Shortcuts")
        Thread.sleep(forTimeInterval: 1)

        let sheetAttachment = XCTAttachment(screenshot: app.screenshot())
        sheetAttachment.name = "Open-in sheet with Shortcuts"
        sheetAttachment.lifetime = .keepAlways
        add(sheetAttachment)

        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        // The sheet may be hosted by the app or by SpringBoard depending on
        // OS version; try whichever exposes the Shortcuts target.
        let candidates = [
            shortcutsTarget,
            springboard.cells["Shortcuts"].firstMatch,
            springboard.buttons["Shortcuts"].firstMatch,
            app.buttons["Shortcuts"].firstMatch
        ]

        for _ in 0..<2 where shortcuts.state != .runningForeground {
            for candidate in candidates where candidate.exists {
                candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

                if shortcuts.wait(for: .runningForeground, timeout: 4) {
                    break
                }
            }
        }

        // Shortcuts foregrounds with its import preview.
        XCTAssertTrue(shortcuts.wait(for: .runningForeground, timeout: 10))

        let importPreview = XCTAttachment(screenshot: shortcuts.screenshot())
        importPreview.name = "Shortcuts import preview"
        importPreview.lifetime = .keepAlways
        add(importPreview)

        let addButton = shortcuts.buttons["Add Shortcut"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Shortcuts did not show the Add Shortcut preview")
        addButton.tap()

        let imported = shortcuts.staticTexts["Log My Purchase"].firstMatch
        XCTAssertTrue(imported.waitForExistence(timeout: 10), "Imported shortcut not visible in library")

        let libraryAttachment = XCTAttachment(screenshot: shortcuts.screenshot())
        libraryAttachment.name = "Shortcuts library after import"
        libraryAttachment.lifetime = .keepAlways
        add(libraryAttachment)
    }

    /// Verifies the signed shortcut file itself: opening it hands off to the
    /// Shortcuts app's import preview and the shortcut lands in the library.
    /// Requires the file planted in the simulator's Files storage first:
    /// cp "Log My Purchase.shortcut" "<sim>/data/Containers/Shared/AppGroup/<LocalStorage>/File Provider Storage/".
    /// Opt-in: run with TEST_RUNNER_RUN_CROSSAPP_TESTS=1.
    @MainActor
    func testSignedShortcutFileImportsViaFilesApp() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_CROSSAPP_TESTS"] == "1",
            "Cross-app test; set RUN_CROSSAPP_TESTS=1 to run."
        )

        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.launch()
        XCTAssertTrue(files.wait(for: .runningForeground, timeout: 10))

        // Get to the local storage root.
        let browseTab = files.buttons["Browse"].firstMatch
        if browseTab.waitForExistence(timeout: 5) {
            browseTab.tap()
            browseTab.tap()
        }

        let onMyIphone = files.staticTexts["On My iPhone"].firstMatch
        if onMyIphone.waitForExistence(timeout: 5) {
            onMyIphone.tap()
        }

        let fileCell = files.cells
            .matching(NSPredicate(format: "label CONTAINS %@", "Log My Purchase"))
            .firstMatch
        XCTAssertTrue(fileCell.waitForExistence(timeout: 8), "Planted shortcut file not visible in Files")

        let filesAttachment = XCTAttachment(screenshot: files.screenshot())
        filesAttachment.name = "Files app with shortcut file"
        filesAttachment.lifetime = .keepAlways
        add(filesAttachment)

        // Tap the icon area — tapping the filename label starts a rename.
        fileCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()

        // Files may open a QuickLook preview with an "open in Shortcuts"
        // toolbar button instead of handing off directly.
        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        let quickLookOpenButton = files.buttons["Shortcuts"].firstMatch

        if !shortcuts.wait(for: .runningForeground, timeout: 5) {
            XCTAssertTrue(quickLookOpenButton.waitForExistence(timeout: 8), "No route from Files into Shortcuts")
            quickLookOpenButton.tap()
        }

        // Opening the file must hand off to the Shortcuts import preview.
        XCTAssertTrue(shortcuts.wait(for: .runningForeground, timeout: 15), "Shortcuts did not open the file")

        let previewAttachment = XCTAttachment(screenshot: shortcuts.screenshot())
        previewAttachment.name = "Shortcuts import preview"
        previewAttachment.lifetime = .keepAlways
        add(previewAttachment)

        // The import sheet may be exposed by the Shortcuts app itself or by
        // its remote-view service; look for the Add button in any host and
        // fall back to its fixed screen position (bottom center).
        Thread.sleep(forTimeInterval: 3)

        let addButtonHosts = [
            shortcuts.buttons["Add Shortcut"].firstMatch,
            files.buttons["Add Shortcut"].firstMatch
        ]

        var tappedAdd = false
        for _ in 0..<3 where !tappedAdd {
            for button in addButtonHosts where button.exists {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                tappedAdd = true
                break
            }

            if !tappedAdd {
                Thread.sleep(forTimeInterval: 3)
            }
        }

        if !tappedAdd {
            // Last resort: the blue Add Shortcut bar sits at the bottom
            // center of the import sheet.
            shortcuts.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
        }

        Thread.sleep(forTimeInterval: 4)

        let postAddAttachment = XCTAttachment(screenshot: shortcuts.screenshot())
        postAddAttachment.name = "Right after Add Shortcut tap"
        postAddAttachment.lifetime = .keepAlways
        add(postAddAttachment)

        // Relaunch Shortcuts so the check runs against the real library, not
        // leftovers of the import sheet.
        shortcuts.terminate()
        shortcuts.launch()
        XCTAssertTrue(shortcuts.wait(for: .runningForeground, timeout: 10))
        Thread.sleep(forTimeInterval: 2)

        let imported = shortcuts.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "Purchase"))
            .firstMatch
        let importedAppeared = imported.waitForExistence(timeout: 10)

        let libraryAttachment = XCTAttachment(screenshot: shortcuts.screenshot())
        libraryAttachment.name = "Shortcuts library after import"
        libraryAttachment.lifetime = .keepAlways
        add(libraryAttachment)

        XCTAssertTrue(importedAppeared, "Imported shortcut not visible in library")
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
