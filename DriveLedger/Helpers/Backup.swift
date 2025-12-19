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
    var maintenanceIntervals: [MaintenanceIntervalBackup]

    init(
        id: UUID,
        name: String,
        make: String?,
        model: String?,
        generation: String?,
        year: Int?,
        engine: String?,
        bodyStyle: String?,
        colorName: String?,
        createdAt: Date,
        licensePlate: String?,
        iconSymbol: String?,
        initialOdometerKm: Int?,
        entries: [LogEntryBackup],
        maintenanceIntervals: [MaintenanceIntervalBackup] = []
    ) {
        self.id = id
        self.name = name
        self.make = make
        self.model = model
        self.generation = generation
        self.year = year
        self.engine = engine
        self.bodyStyle = bodyStyle
        self.colorName = colorName
        self.createdAt = createdAt
        self.licensePlate = licensePlate
        self.iconSymbol = iconSymbol
        self.initialOdometerKm = initialOdometerKm
        self.entries = entries
        self.maintenanceIntervals = maintenanceIntervals
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        make = try c.decodeIfPresent(String.self, forKey: .make)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        generation = try c.decodeIfPresent(String.self, forKey: .generation)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        engine = try c.decodeIfPresent(String.self, forKey: .engine)
        bodyStyle = try c.decodeIfPresent(String.self, forKey: .bodyStyle)
        colorName = try c.decodeIfPresent(String.self, forKey: .colorName)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        licensePlate = try c.decodeIfPresent(String.self, forKey: .licensePlate)
        iconSymbol = try c.decodeIfPresent(String.self, forKey: .iconSymbol)
        initialOdometerKm = try c.decodeIfPresent(Int.self, forKey: .initialOdometerKm)
        entries = try c.decodeIfPresent([LogEntryBackup].self, forKey: .entries) ?? []
        maintenanceIntervals = try c.decodeIfPresent([MaintenanceIntervalBackup].self, forKey: .maintenanceIntervals) ?? []
    }
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

    var maintenanceIntervalID: UUID?

    var purchaseCategory: String?
    var purchaseVendor: String?
    
    var tollZone: String?
    var carwashLocation: String?
    var parkingLocation: String?
    var finesViolationType: String?
}

struct MaintenanceIntervalBackup: Codable {
    var id: UUID
    var title: String
    var intervalKm: Int?
    var intervalMonths: Int?
    var lastDoneDate: Date?
    var lastDoneOdometerKm: Int?
    var notes: String?
    var isEnabled: Bool

    init(
        id: UUID,
        title: String,
        intervalKm: Int?,
        intervalMonths: Int?,
        lastDoneDate: Date?,
        lastDoneOdometerKm: Int?,
        notes: String?,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
        self.lastDoneDate = lastDoneDate
        self.lastDoneOdometerKm = lastDoneOdometerKm
        self.notes = notes
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        intervalKm = try c.decodeIfPresent(Int.self, forKey: .intervalKm)
        intervalMonths = try c.decodeIfPresent(Int.self, forKey: .intervalMonths)
        lastDoneDate = try c.decodeIfPresent(Date.self, forKey: .lastDoneDate)
        lastDoneOdometerKm = try c.decodeIfPresent(Int.self, forKey: .lastDoneOdometerKm)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

enum DriveLedgerBackupCodec {
    static let currentFormatVersion = 2

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
                            maintenanceIntervalID: entry.maintenanceIntervalID,
                            purchaseCategory: entry.purchaseCategory,
                            purchaseVendor: entry.purchaseVendor,
                            tollZone: entry.tollZone,
                            carwashLocation: entry.carwashLocation,
                            parkingLocation: entry.parkingLocation,
                            finesViolationType: entry.finesViolationType
                        )
                    },
                    maintenanceIntervals: vehicle.maintenanceIntervals.map { interval in
                        MaintenanceIntervalBackup(
                            id: interval.id,
                            title: interval.title,
                            intervalKm: interval.intervalKm,
                            intervalMonths: interval.intervalMonths,
                            lastDoneDate: interval.lastDoneDate,
                            lastDoneOdometerKm: interval.lastDoneOdometerKm,
                            notes: interval.notes,
                            isEnabled: interval.isEnabled
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
        var maintenanceIntervalsUpserted: Int
    }

    static func importData(_ data: Data, into modelContext: ModelContext) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(DriveLedgerBackup.self, from: data)

        var vehiclesUpserted = 0
        var entriesUpserted = 0
        var maintenanceIntervalsUpserted = 0

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
                entry.maintenanceIntervalID = entryBackup.maintenanceIntervalID

                entry.purchaseCategory = entryBackup.purchaseCategory
                entry.purchaseVendor = entryBackup.purchaseVendor
                
                entry.tollZone = entryBackup.tollZone
                entry.carwashLocation = entryBackup.carwashLocation
                entry.parkingLocation = entryBackup.parkingLocation
                entry.finesViolationType = entryBackup.finesViolationType

                entry.vehicle = vehicle
                entriesUpserted += 1
            }
            
            let uniqueIntervals = Dictionary(vehicleBackup.maintenanceIntervals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for intervalBackup in uniqueIntervals.values {
                let interval: MaintenanceInterval
                let intervalID = intervalBackup.id
                let intervalFetch = FetchDescriptor<MaintenanceInterval>(predicate: #Predicate { $0.id == intervalID })
                if let existing = try modelContext.fetch(intervalFetch).first {
                    interval = existing
                } else {
                    interval = MaintenanceInterval(
                        id: intervalBackup.id,
                        title: intervalBackup.title,
                        intervalKm: intervalBackup.intervalKm,
                        intervalMonths: intervalBackup.intervalMonths,
                        lastDoneDate: intervalBackup.lastDoneDate,
                        lastDoneOdometerKm: intervalBackup.lastDoneOdometerKm,
                        notes: intervalBackup.notes,
                        isEnabled: intervalBackup.isEnabled,
                        vehicle: vehicle
                    )
                    modelContext.insert(interval)
                }
                
                interval.title = intervalBackup.title
                interval.intervalKm = intervalBackup.intervalKm
                interval.intervalMonths = intervalBackup.intervalMonths
                interval.lastDoneDate = intervalBackup.lastDoneDate
                interval.lastDoneOdometerKm = intervalBackup.lastDoneOdometerKm
                interval.notes = intervalBackup.notes
                interval.isEnabled = intervalBackup.isEnabled
                interval.vehicle = vehicle
                maintenanceIntervalsUpserted += 1
            }
        }

        try modelContext.save()
        return ImportSummary(
            vehiclesUpserted: vehiclesUpserted, 
            entriesUpserted: entriesUpserted,
            maintenanceIntervalsUpserted: maintenanceIntervalsUpserted
        )
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
