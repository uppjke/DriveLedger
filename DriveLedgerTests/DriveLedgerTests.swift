//
//  DriveLedgerTests.swift
//  DriveLedgerTests
//
//  Created by Vadim Gusev on 14.12.2025.
//

import XCTest
import SwiftData
@testable import DriveLedger

final class DriveLedgerTests: XCTestCase {

    @MainActor
    private func makeInMemoryModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Vehicle.self,
            LogEntry.self,
            MaintenanceInterval.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

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

    func testBackup_exportImport_roundTripRestoresVehiclesAndEntries() async throws {
        let vehicleID = UUID()
        let entryID = UUID()

        struct ImportedVehicleSnapshot: Equatable {
            var id: UUID
            var name: String
            var licensePlate: String?
        }

        struct ImportedEntrySnapshot: Equatable {
            var id: UUID
            var kindRaw: String
            var fuelLiters: Double?
            var fuelPricePerLiter: Double?
            var fuelStation: String?
            var vehicleID: UUID?
        }

        let (vehiclesUpserted, entriesUpserted, importedVehicle, importedEntry) = try await MainActor.run {
            // Export
            let exportContainer = try makeInMemoryModelContainer()
            let exportContext = exportContainer.mainContext

            let vehicle = Vehicle(
                id: vehicleID,
                name: "Test car",
                make: "Toyota",
                model: "Camry",
                generation: "XV70",
                year: 2020,
                engine: "2.5",
                bodyStyle: "sedan",
                colorName: "white",
                createdAt: Date(timeIntervalSinceReferenceDate: 123),
                licensePlate: "А123ВС77",
                iconSymbol: "car.fill",
                initialOdometerKm: 1000
            )
            exportContext.insert(vehicle)

            let entry = LogEntry(
                id: entryID,
                kind: .fuel,
                date: Date(timeIntervalSinceReferenceDate: 456),
                odometerKm: 1200,
                totalCost: 2500,
                notes: "note",
                vehicle: vehicle
            )
            entry.fuelLiters = 30
            entry.fuelPricePerLiter = 55.5
            entry.fuelStation = "Shell"
            entry.fuelFillKindRaw = FuelFillKind.full.rawValue
            exportContext.insert(entry)

            try exportContext.save()
            let data = try DriveLedgerBackupCodec.exportData(from: exportContext)

            // Import into a fresh store
            let importContainer = try makeInMemoryModelContainer()
            let importContext = importContainer.mainContext
            let summary = try DriveLedgerBackupCodec.importData(data, into: importContext)

            let vehicles = try importContext.fetch(FetchDescriptor<Vehicle>())
            let entries = try importContext.fetch(FetchDescriptor<LogEntry>())

            let importedVehicle = ImportedVehicleSnapshot(
                id: vehicles.first?.id ?? UUID(),
                name: vehicles.first?.name ?? "",
                licensePlate: vehicles.first?.licensePlate
            )

            let importedEntry = ImportedEntrySnapshot(
                id: entries.first?.id ?? UUID(),
                kindRaw: entries.first?.kindRaw ?? "",
                fuelLiters: entries.first?.fuelLiters,
                fuelPricePerLiter: entries.first?.fuelPricePerLiter,
                fuelStation: entries.first?.fuelStation,
                vehicleID: entries.first?.vehicle?.id
            )

            return (summary.vehiclesUpserted, summary.entriesUpserted, importedVehicle, importedEntry)
        }

        XCTAssertEqual(vehiclesUpserted, 1)
        XCTAssertEqual(entriesUpserted, 1)
        XCTAssertEqual(importedVehicle.id, vehicleID)
        XCTAssertEqual(importedVehicle.name, "Test car")
        XCTAssertEqual(importedVehicle.licensePlate, "А123ВС77")
        XCTAssertEqual(importedEntry.id, entryID)
        XCTAssertEqual(importedEntry.kindRaw, LogEntryKind.fuel.rawValue)
        XCTAssertEqual(importedEntry.fuelLiters, 30)
        XCTAssertEqual(importedEntry.fuelPricePerLiter, 55.5)
        XCTAssertEqual(importedEntry.fuelStation, "Shell")
        XCTAssertEqual(importedEntry.vehicleID, vehicleID)
    }

        func testBackup_import_v1WithoutMaintenanceIntervalsKey_succeeds() async throws {
                let vehicleID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                let exportedAt = "2025-12-19T00:00:00Z"
                let createdAt = "2025-12-19T00:00:00Z"

                let json = """
                {
                    "exportedAt": "\(exportedAt)",
                    "formatVersion": 1,
                    "vehicles": [
                        {
                            "createdAt": "\(createdAt)",
                            "entries": [],
                            "id": "\(vehicleID.uuidString)",
                            "name": "V"
                        }
                    ]
                }
                """

                let data = Data(json.utf8)

                let (summary, vehiclesCount, entriesCount) = try await MainActor.run {
                        let container = try makeInMemoryModelContainer()
                        let context = container.mainContext
                        let summary = try DriveLedgerBackupCodec.importData(data, into: context)
                        let vehicles = try context.fetch(FetchDescriptor<Vehicle>())
                        let entries = try context.fetch(FetchDescriptor<LogEntry>())
                        return (summary, vehicles.count, entries.count)
                }

                XCTAssertEqual(summary.vehiclesUpserted, 1)
                XCTAssertEqual(summary.entriesUpserted, 0)
                XCTAssertEqual(summary.maintenanceIntervalsUpserted, 0)
                XCTAssertEqual(vehiclesCount, 1)
                XCTAssertEqual(entriesCount, 0)
        }
}
