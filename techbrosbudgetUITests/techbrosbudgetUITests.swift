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

        XCTAssertTrue(app.images["Tech Bros logo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Tech Bros Budget"].exists)
        XCTAssertTrue(app.staticTexts["Fast manual expense logging with async category cleanup."].exists)
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
}
