import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DriveLedgerBackup: Codable {
    var formatVersion: Int
    var exportedAt: Date
    var vehicles: [VehicleBackup]
}

struct VehicleBackup: Codable {
    var id: UUID
    var name: String
    var make: String?
    var model: String?
    var generation: String?
    var year: Int?
    var engine: String?
    var bodyStyle: String?
    var colorName: String?
    var createdAt: Date
    var licensePlate: String?
    var iconSymbol: String?
    var initialOdometerKm: Int?
    var entries: [LogEntryBackup]
}

struct LogEntryBackup: Codable {
    var id: UUID

    var kindRaw: String
    var date: Date
    var odometerKm: Int?

    var totalCost: Double?
    var notes: String?

    var fuelLiters: Double?
    var fuelPricePerLiter: Double?
    var fuelStation: String?
    var fuelConsumptionLPer100km: Double?
    var fuelFillKindRaw: String?

    var serviceTitle: String?
    var serviceDetails: String?

    var purchaseCategory: String?
    var purchaseVendor: String?
}

enum DriveLedgerBackupCodec {
    static let currentFormatVersion = 1

    static func exportData(from modelContext: ModelContext) throws -> Data {
        let vehicles = try modelContext.fetch(
            FetchDescriptor<Vehicle>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )

        let payload = DriveLedgerBackup(
            formatVersion: currentFormatVersion,
            exportedAt: Date(),
            vehicles: vehicles.map { vehicle in
                let entries = vehicle.entries.sorted {
                    if $0.date != $1.date { return $0.date < $1.date }
                    let a = $0.odometerKm ?? Int.min
                    let b = $1.odometerKm ?? Int.min
                    if a != b { return a < b }
                    return $0.id.uuidString < $1.id.uuidString
                }

                return VehicleBackup(
                    id: vehicle.id,
                    name: vehicle.name,
                    make: vehicle.make,
                    model: vehicle.model,
                    generation: vehicle.generation,
                    year: vehicle.year,
                    engine: vehicle.engine,
                    bodyStyle: vehicle.bodyStyle,
                    colorName: vehicle.colorName,
                    createdAt: vehicle.createdAt,
                    licensePlate: vehicle.licensePlate,
                    iconSymbol: vehicle.iconSymbol,
                    initialOdometerKm: vehicle.initialOdometerKm,
                    entries: entries.map { entry in
                        LogEntryBackup(
                            id: entry.id,
                            kindRaw: entry.kindRaw,
                            date: entry.date,
                            odometerKm: entry.odometerKm,
                            totalCost: entry.totalCost,
                            notes: entry.notes,
                            fuelLiters: entry.fuelLiters,
                            fuelPricePerLiter: entry.fuelPricePerLiter,
                            fuelStation: entry.fuelStation,
                            fuelConsumptionLPer100km: entry.fuelConsumptionLPer100km,
                            fuelFillKindRaw: entry.fuelFillKindRaw,
                            serviceTitle: entry.serviceTitle,
                            serviceDetails: entry.serviceDetails,
                            purchaseCategory: entry.purchaseCategory,
                            purchaseVendor: entry.purchaseVendor
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    struct ImportSummary: Equatable {
        var vehiclesUpserted: Int
        var entriesUpserted: Int
    }

    static func importData(_ data: Data, into modelContext: ModelContext) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(DriveLedgerBackup.self, from: data)

        var vehiclesUpserted = 0
        var entriesUpserted = 0

        // De-dup within the backup itself.
        let uniqueVehicles = Dictionary(payload.vehicles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for vehicleBackup in uniqueVehicles.values {
            let vehicle: Vehicle
            do {
                let id = vehicleBackup.id
                let fetch = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == id })
                if let existing = try modelContext.fetch(fetch).first {
                    vehicle = existing
                } else {
                    vehicle = Vehicle(
                        id: vehicleBackup.id,
                        name: vehicleBackup.name,
                        make: vehicleBackup.make,
                        model: vehicleBackup.model,
                        generation: vehicleBackup.generation,
                        year: vehicleBackup.year,
                        engine: vehicleBackup.engine,
                        bodyStyle: vehicleBackup.bodyStyle,
                        colorName: vehicleBackup.colorName,
                        createdAt: vehicleBackup.createdAt,
                        licensePlate: vehicleBackup.licensePlate,
                        iconSymbol: vehicleBackup.iconSymbol,
                        initialOdometerKm: vehicleBackup.initialOdometerKm
                    )
                    modelContext.insert(vehicle)
                }
            } catch {
                throw error
            }

            vehicle.name = vehicleBackup.name
            vehicle.make = vehicleBackup.make
            vehicle.model = vehicleBackup.model
            vehicle.generation = vehicleBackup.generation
            vehicle.year = vehicleBackup.year
            vehicle.engine = vehicleBackup.engine
            vehicle.bodyStyle = vehicleBackup.bodyStyle
            vehicle.colorName = vehicleBackup.colorName
            vehicle.createdAt = vehicleBackup.createdAt
            vehicle.licensePlate = vehicleBackup.licensePlate
            vehicle.iconSymbol = vehicleBackup.iconSymbol
            vehicle.initialOdometerKm = vehicleBackup.initialOdometerKm
            vehiclesUpserted += 1

            let uniqueEntries = Dictionary(vehicleBackup.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for entryBackup in uniqueEntries.values {
                let entry: LogEntry
                let entryID = entryBackup.id
                let entryFetch = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.id == entryID })
                if let existing = try modelContext.fetch(entryFetch).first {
                    entry = existing
                } else {
                    let kind = LogEntryKind(rawValue: entryBackup.kindRaw) ?? .note
                    entry = LogEntry(
                        id: entryBackup.id,
                        kind: kind,
                        date: entryBackup.date,
                        odometerKm: entryBackup.odometerKm,
                        totalCost: entryBackup.totalCost,
                        notes: entryBackup.notes,
                        vehicle: vehicle
                    )
                    modelContext.insert(entry)
                }

                entry.kindRaw = entryBackup.kindRaw
                entry.date = entryBackup.date
                entry.odometerKm = entryBackup.odometerKm
                entry.totalCost = entryBackup.totalCost
                entry.notes = entryBackup.notes

                entry.fuelLiters = entryBackup.fuelLiters
                entry.fuelPricePerLiter = entryBackup.fuelPricePerLiter
                entry.fuelStation = entryBackup.fuelStation
                entry.fuelConsumptionLPer100km = entryBackup.fuelConsumptionLPer100km
                entry.fuelFillKindRaw = entryBackup.fuelFillKindRaw

                entry.serviceTitle = entryBackup.serviceTitle
                entry.serviceDetails = entryBackup.serviceDetails

                entry.purchaseCategory = entryBackup.purchaseCategory
                entry.purchaseVendor = entryBackup.purchaseVendor

                entry.vehicle = vehicle
                entriesUpserted += 1
            }
        }

        try modelContext.save()
        return ImportSummary(vehiclesUpserted: vehiclesUpserted, entriesUpserted: entriesUpserted)
    }
}

struct DriveLedgerBackupDocument: FileDocument, Identifiable {
    static var readableContentTypes: [UTType] { [.json] }

    let id = UUID()
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
