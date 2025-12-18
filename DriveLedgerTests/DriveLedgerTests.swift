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

    func testFuelConsumption_series_afterOdometerAddedLater() {
        // Given: two FULL fuel entries that initially had no odometer (common real-world flow)
        let v = Vehicle(name: "Test")

        let e1 = LogEntry(kind: .fuel, date: Date(timeIntervalSinceReferenceDate: 10), odometerKm: nil, totalCost: 100, notes: nil, vehicle: v)
        e1.fuelFillKind = .full
        e1.fuelLiters = 10

        let e2 = LogEntry(kind: .fuel, date: Date(timeIntervalSinceReferenceDate: 20), odometerKm: nil, totalCost: 120, notes: nil, vehicle: v)
        e2.fuelFillKind = .full
        e2.fuelLiters = 20

        // When: user later edits both entries and adds odometer values
        e1.odometerKm = 1000
        e2.odometerKm = 1200

    // Then: default series (per-fill-up) should contain 1 point (needs 2 fuel entries with odo)
    let series = FuelConsumption.series(existingEntries: [e1, e2])
        XCTAssertEqual(series.count, 1)

        // And the computed value matches expected
        // liters between prev full and current full includes only current full for this simplest case
        // distance = 200 km, liters = 20 => 10.0 l/100km
        XCTAssertEqual(series[0].value, 10.0, accuracy: 0.0001)

        // Full-to-full correctness is covered separately in testFuelConsumption_fullToFull_includesPartialsBetween().
    }

    func testVehicleCatalog_inferredBodyStyle_domesticLadaVestaIsSedan() {
        XCTAssertEqual(
            VehicleCatalog.inferredBodyStyle(make: "Лада", model: "Веста"),
            VehicleBodyStyleOption.sedan.rawValue
        )
    }

    func testVehicleCatalog_inferredBodyStyle_domesticVAZClassicIsSedan() {
        XCTAssertEqual(
            VehicleCatalog.inferredBodyStyle(make: "ВАЗ", model: "2106"),
            VehicleBodyStyleOption.sedan.rawValue
        )
    }

    func testVehicleCatalog_inferredBodyStyle_domesticVAZ2111IsWagon() {
        XCTAssertEqual(
            VehicleCatalog.inferredBodyStyle(make: "ВАЗ", model: "2111"),
            VehicleBodyStyleOption.wagon.rawValue
        )
    }

    func testVehicleCatalog_inferredBodyStyle_domesticUAZBukhankaIsVan() {
        XCTAssertEqual(
            VehicleCatalog.inferredBodyStyle(make: "УАЗ", model: "Буханка"),
            VehicleBodyStyleOption.van.rawValue
        )
    }

    func testVehicleCatalog_inferredBodyStyle_domesticMoskvich3IsCrossover() {
        XCTAssertEqual(
            VehicleCatalog.inferredBodyStyle(make: "Москвич", model: "3"),
            VehicleBodyStyleOption.crossover.rawValue
        )
    }

    func testVehicleCatalog_inferredBodyStyle_makeAliasesAreApplied() {
        XCTAssertEqual(
            VehicleCatalog.inferredBodyStyle(make: "LADA", model: "Веста"),
            VehicleBodyStyleOption.sedan.rawValue
        )
        XCTAssertEqual(
            VehicleCatalog.inferredBodyStyle(make: "UAZ", model: "Буханка"),
            VehicleBodyStyleOption.van.rawValue
        )
    }

    func testVehicleCatalog_inferredBodyStyle_keywordFallbackDetectsPickup() {
        XCTAssertEqual(
            VehicleCatalog.inferredBodyStyle(make: "SomeMake", model: "Super Pickup"),
            VehicleBodyStyleOption.pickup.rawValue
        )
    }

    func testVehicleCatalog_inferredBodyStyle_emptyInputsReturnNil() {
        XCTAssertNil(VehicleCatalog.inferredBodyStyle(make: "", model: ""))
        XCTAssertNil(VehicleCatalog.inferredBodyStyle(make: "Лада", model: ""))
        XCTAssertNil(VehicleCatalog.inferredBodyStyle(make: "", model: "Веста"))
    }

    func testVehicleBodyStyleOption_symbolNames_areStableForCoreCases() {
        XCTAssertEqual(VehicleBodyStyleOption.sedan.symbolName, "car.fill")
        XCTAssertEqual(VehicleBodyStyleOption.suv.symbolName, "suv.side.front.fill")
        XCTAssertEqual(VehicleBodyStyleOption.van.symbolName, "bus.fill")
        XCTAssertEqual(VehicleBodyStyleOption.pickup.symbolName, "truck.pickup.side.fill")
    }
}
