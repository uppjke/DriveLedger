//
//  DriveLedgerUITests.swift
//  DriveLedgerUITests
//
//  Created by Vadim Gusev on 14.12.2025.
//

import XCTest

final class DriveLedgerUITests: XCTestCase {

    private let seededVehicleID = "00000000-0000-0000-0000-000000000001"

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        return app
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testVehicleTapOpensDetail() throws {
        let app = makeApp()
        app.launch()

        let vehicleName = app.staticTexts["Test Car"]
        XCTAssertTrue(vehicleName.waitForExistence(timeout: 5), "Seeded vehicle row should exist")

        vehicleName.tap()

        XCTAssertTrue(
            app.navigationBars["Test Car"].waitForExistence(timeout: 5),
            "Tapping a vehicle should open its detail screen"
        )
    }

    @MainActor
    func testVehicleSelectionHasNoMaintenanceEntry() throws {
        let app = makeApp()
        app.launch()

        // Ensure we're on the vehicle selection screen.
        let vehicleName = app.staticTexts["Test Car"]
        XCTAssertTrue(vehicleName.waitForExistence(timeout: 5))

        // Requirement: no Maintenance entry/button on the vehicle selection screen.
        XCTAssertFalse(app.staticTexts["Maintenance"].exists)
    }

}
