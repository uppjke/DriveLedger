//
//  DriveLedgerTests.swift
//  DriveLedgerTests
//
//  Created by Vadim Gusev on 14.12.2025.
//

import XCTest
@testable import DriveLedger

final class DriveLedgerTests: XCTestCase {

    func testTextParsing_parseDouble_acceptsCommaDecimal() {
        XCTAssertEqual(TextParsing.parseDouble("12,5") ?? -1, 12.5, accuracy: 0.000_001)
        XCTAssertEqual(TextParsing.parseDouble("  12,5  ") ?? -1, 12.5, accuracy: 0.000_001)
    }

    func testTextParsing_cleanOptional_trimsAndDropsEmpty() {
        XCTAssertNil(TextParsing.cleanOptional("   \n\t  "))
        XCTAssertEqual(TextParsing.cleanOptional("  hi  "), "hi")
    }

    func testCSVExport_escapesQuotesSemicolonsAndNewlines() {
        let v = Vehicle(name: "My;Car \"Test\"\nLine")

        let e = LogEntry(kind: .note)
        e.notes = "Hello;\"World\"\nNext"
        e.totalCost = 123.45
        e.vehicle = v

        guard let url = CSVExport.makeVehicleCSVExportURL(vehicleName: v.name, entries: [e]) else {
            return XCTFail("Expected CSV export URL")
        }

        let csv = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        XCTAssertTrue(csv.contains("\"My;Car \"\"Test\"\"\nLine\""))
        XCTAssertTrue(csv.contains("\"Hello;\"\"World\"\"\nNext\""))
    }

    func testFuelConsumption_fullToFull_includesPartialsBetween() {
        let vehicle = Vehicle(name: "V")

        let prevFull = LogEntry(kind: .fuel)
        prevFull.vehicle = vehicle
        prevFull.date = Date(timeIntervalSince1970: 1)
        prevFull.odometerKm = 10_000
        prevFull.fuelLiters = 40
        prevFull.fuelFillKind = .full

        let partial = LogEntry(kind: .fuel)
        partial.vehicle = vehicle
        partial.date = Date(timeIntervalSince1970: 2)
        partial.odometerKm = 10_200
        partial.fuelLiters = 10
        partial.fuelFillKind = .partial

        // Current FULL (draft liters) at 10_400.
        let draftLiters: Double = 35
        let cons = FuelConsumption.compute(
            currentEntryID: nil,
            currentDate: Date(timeIntervalSince1970: 3),
            currentOdo: 10_400,
            currentLitersDraft: draftLiters,
            currentFillKind: .full,
            existingEntries: [prevFull, partial]
        )

        // litersSum = 10 + 35, distance = 400 => 11.25 l/100km
        XCTAssertEqual(cons ?? -1, 11.25, accuracy: 0.000_001)
    }
}
