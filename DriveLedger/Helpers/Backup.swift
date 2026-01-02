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
    var vin: String?
    var iconSymbol: String?
    var initialOdometerKm: Int?
    var entries: [LogEntryBackup]
    var maintenanceIntervals: [MaintenanceIntervalBackup]
    var serviceBookEntries: [ServiceBookEntryBackup]

    var wheelSets: [WheelSetBackup]?
    var currentWheelSetID: UUID?

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
        vin: String?,
        iconSymbol: String?,
        initialOdometerKm: Int?,
        entries: [LogEntryBackup],
        maintenanceIntervals: [MaintenanceIntervalBackup] = [],
        serviceBookEntries: [ServiceBookEntryBackup] = [],
        wheelSets: [WheelSetBackup]? = nil,
        currentWheelSetID: UUID? = nil
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
        self.vin = vin
        self.iconSymbol = iconSymbol
        self.initialOdometerKm = initialOdometerKm
        self.entries = entries
        self.maintenanceIntervals = maintenanceIntervals
        self.serviceBookEntries = serviceBookEntries

        self.wheelSets = wheelSets
        self.currentWheelSetID = currentWheelSetID
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
        vin = try c.decodeIfPresent(String.self, forKey: .vin)
        iconSymbol = try c.decodeIfPresent(String.self, forKey: .iconSymbol)
        initialOdometerKm = try c.decodeIfPresent(Int.self, forKey: .initialOdometerKm)
        entries = try c.decodeIfPresent([LogEntryBackup].self, forKey: .entries) ?? []
        maintenanceIntervals = try c.decodeIfPresent([MaintenanceIntervalBackup].self, forKey: .maintenanceIntervals) ?? []
        serviceBookEntries = try c.decodeIfPresent([ServiceBookEntryBackup].self, forKey: .serviceBookEntries) ?? []

        wheelSets = try c.decodeIfPresent([WheelSetBackup].self, forKey: .wheelSets)
        currentWheelSetID = try c.decodeIfPresent(UUID.self, forKey: .currentWheelSetID)
    }
}

struct WheelSetBackup: Codable {
    var id: UUID
    var name: String
    var tireSize: String?
    var tireSeasonRaw: String?
    var winterTireKindRaw: String?
    var rimTypeRaw: String?
    var rimDiameterInches: Int?
    var rimWidthInches: Double?
    var rimOffsetET: Int?
    var rimSpec: String?
    var createdAt: Date
}

struct PurchaseItemBackup: Codable {
    var title: String
    var price: Double?
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
    var maintenanceIntervalIDs: [UUID]?

    var serviceChecklistItems: [String]?

    var purchaseCategory: String?
    var purchaseVendor: String?
    var purchaseItems: [PurchaseItemBackup]?
    
    var tollZone: String?
    var carwashLocation: String?
    var parkingLocation: String?
    var finesViolationType: String?

    var wheelSetID: UUID?

    var attachments: [AttachmentBackup]?
}

struct AttachmentBackup: Codable {
    var id: UUID
    var createdAt: Date
    var originalFileName: String
    var uti: String
    var fileExtension: String?
    var fileSizeBytes: Int?
    var dataBase64: String?
    var maintenanceIntervalIDs: [UUID]?
    var appliesToAllMaintenanceIntervals: Bool?
}

struct MaintenanceIntervalBackup: Codable {
    var id: UUID
    var title: String
    var templateID: String?
    var intervalKm: Int?
    var intervalMonths: Int?
    var lastDoneDate: Date?
    var lastDoneOdometerKm: Int?
    var notificationsEnabled: Bool
    var notificationsByDateEnabled: Bool
    var notificationsByMileageEnabled: Bool
    var notificationLeadDays: Int
    var notificationLeadKm: Int?
    var notificationTimeMinutes: Int
    var notificationRepeatRaw: String
    var notes: String?
    var isEnabled: Bool

    init(
        id: UUID,
        title: String,
        templateID: String? = nil,
        intervalKm: Int?,
        intervalMonths: Int?,
        lastDoneDate: Date?,
        lastDoneOdometerKm: Int?,
        notificationsEnabled: Bool = false,
        notificationsByDateEnabled: Bool = true,
        notificationsByMileageEnabled: Bool = true,
        notificationLeadDays: Int = 30,
        notificationLeadKm: Int? = nil,
        notificationTimeMinutes: Int = 9 * 60,
        notificationRepeatRaw: String = "none",
        notes: String?,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.templateID = templateID
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
        self.lastDoneDate = lastDoneDate
        self.lastDoneOdometerKm = lastDoneOdometerKm
        self.notificationsEnabled = notificationsEnabled
        self.notificationsByDateEnabled = notificationsByDateEnabled
        self.notificationsByMileageEnabled = notificationsByMileageEnabled
        self.notificationLeadDays = notificationLeadDays
        self.notificationLeadKm = notificationLeadKm
        self.notificationTimeMinutes = notificationTimeMinutes
        self.notificationRepeatRaw = notificationRepeatRaw
        self.notes = notes
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        templateID = try c.decodeIfPresent(String.self, forKey: .templateID)
        intervalKm = try c.decodeIfPresent(Int.self, forKey: .intervalKm)
        intervalMonths = try c.decodeIfPresent(Int.self, forKey: .intervalMonths)
        lastDoneDate = try c.decodeIfPresent(Date.self, forKey: .lastDoneDate)
        lastDoneOdometerKm = try c.decodeIfPresent(Int.self, forKey: .lastDoneOdometerKm)
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        notificationsByDateEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsByDateEnabled) ?? true
        notificationsByMileageEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsByMileageEnabled) ?? true
        notificationLeadDays = try c.decodeIfPresent(Int.self, forKey: .notificationLeadDays) ?? 30
        notificationLeadKm = try c.decodeIfPresent(Int.self, forKey: .notificationLeadKm)
        notificationTimeMinutes = try c.decodeIfPresent(Int.self, forKey: .notificationTimeMinutes) ?? 9 * 60
        notificationRepeatRaw = try c.decodeIfPresent(String.self, forKey: .notificationRepeatRaw) ?? "none"
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

struct ServiceBookEntryBackup: Codable {
    var id: UUID

    var intervalID: UUID
    var title: String
    var date: Date
    var odometerKm: Int?

    var performedByRaw: String
    var serviceName: String?

    var oilBrand: String?
    var oilViscosity: String?
    var oilSpec: String?

    var notes: String?
}

enum DriveLedgerBackupCodec {
    static let currentFormatVersion = 7

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
                    vin: vehicle.vin,
                    iconSymbol: vehicle.iconSymbol,
                    initialOdometerKm: vehicle.initialOdometerKm,
                    entries: entries.map { entry in
                        let linked = entry.linkedMaintenanceIntervalIDs
                        let attachments: [AttachmentBackup]? = {
                            guard !entry.attachments.isEmpty else { return nil }
                            return entry.attachments.map { att in
                                let ext = URL(fileURLWithPath: att.originalFileName).pathExtension
                                let appliesToAll = att.appliesToAllMaintenanceIntervals
                                let scoped = att.scopedMaintenanceIntervalIDs
                                return AttachmentBackup(
                                    id: att.id,
                                    createdAt: att.createdAt,
                                    originalFileName: att.originalFileName,
                                    uti: att.uti,
                                    fileExtension: ext.isEmpty ? nil : ext,
                                    fileSizeBytes: att.fileSizeBytes,
                                    dataBase64: AttachmentsStore.readBase64(relativePath: att.relativePath),
                                    maintenanceIntervalIDs: appliesToAll ? nil : scoped,
                                    appliesToAllMaintenanceIntervals: appliesToAll ? nil : false
                                )
                            }
                        }()
                        return LogEntryBackup(
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
                            maintenanceIntervalID: linked.count == 1 ? linked.first : entry.maintenanceIntervalID,
                            maintenanceIntervalIDs: linked.isEmpty ? nil : linked,
                            serviceChecklistItems: entry.serviceChecklistItems.isEmpty ? nil : entry.serviceChecklistItems,
                            purchaseCategory: entry.purchaseCategory,
                            purchaseVendor: entry.purchaseVendor,
                            purchaseItems: entry.purchaseItems.isEmpty
                                ? nil
                                : entry.purchaseItems.map { PurchaseItemBackup(title: $0.title, price: $0.price) },
                            tollZone: entry.tollZone,
                            carwashLocation: entry.carwashLocation,
                            parkingLocation: entry.parkingLocation,
                            finesViolationType: entry.finesViolationType,
                            wheelSetID: entry.wheelSetID,
                            attachments: attachments
                        )
                    },
                    maintenanceIntervals: vehicle.maintenanceIntervals.map { interval in
                        MaintenanceIntervalBackup(
                            id: interval.id,
                            title: interval.title,
                            templateID: interval.templateID,
                            intervalKm: interval.intervalKm,
                            intervalMonths: interval.intervalMonths,
                            lastDoneDate: interval.lastDoneDate,
                            lastDoneOdometerKm: interval.lastDoneOdometerKm,
                            notificationsEnabled: interval.notificationsEnabled,
                            notificationsByDateEnabled: interval.notificationsByDateEnabled,
                            notificationsByMileageEnabled: interval.notificationsByMileageEnabled,
                            notificationLeadDays: interval.notificationLeadDays,
                            notificationLeadKm: interval.notificationLeadKm,
                            notificationTimeMinutes: interval.notificationTimeMinutes,
                            notificationRepeatRaw: interval.notificationRepeatRaw,
                            notes: interval.notes,
                            isEnabled: interval.isEnabled
                        )
                    },
                    serviceBookEntries: vehicle.serviceBookEntries.map { e in
                        ServiceBookEntryBackup(
                            id: e.id,
                            intervalID: e.intervalID,
                            title: e.title,
                            date: e.date,
                            odometerKm: e.odometerKm,
                            performedByRaw: e.performedByRaw,
                            serviceName: e.serviceName,
                            oilBrand: e.oilBrand,
                            oilViscosity: e.oilViscosity,
                            oilSpec: e.oilSpec,
                            notes: e.notes
                        )
                    }
                    ,
                    wheelSets: vehicle.wheelSets.isEmpty ? nil : vehicle.wheelSets.map { ws in
                        WheelSetBackup(
                            id: ws.id,
                            name: ws.name,
                            tireSize: ws.tireSize,
                            tireSeasonRaw: ws.tireSeasonRaw,
                            winterTireKindRaw: ws.winterTireKindRaw,
                            rimTypeRaw: ws.rimTypeRaw,
                            rimDiameterInches: ws.rimDiameterInches,
                            rimWidthInches: ws.rimWidthInches,
                            rimOffsetET: ws.rimOffsetET,
                            rimSpec: ws.rimSpec,
                            createdAt: ws.createdAt
                        )
                    },
                    currentWheelSetID: vehicle.currentWheelSetID
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
        var serviceBookEntriesUpserted: Int
    }

    static func importData(_ data: Data, into modelContext: ModelContext) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(DriveLedgerBackup.self, from: data)
        let formatVersion = payload.formatVersion

        var vehiclesUpserted = 0
        var entriesUpserted = 0
        var maintenanceIntervalsUpserted = 0
        var serviceBookEntriesUpserted = 0

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
                        vin: vehicleBackup.vin,
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
            vehicle.vin = vehicleBackup.vin
            vehicle.iconSymbol = vehicleBackup.iconSymbol
            vehicle.initialOdometerKm = vehicleBackup.initialOdometerKm

            if formatVersion >= 5 {
                let uniqueWheelSets = Dictionary((vehicleBackup.wheelSets ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                for wsBackup in uniqueWheelSets.values {
                    let ws: WheelSet
                    let id = wsBackup.id
                    let fetch = FetchDescriptor<WheelSet>(predicate: #Predicate { $0.id == id })
                    if let existing = try modelContext.fetch(fetch).first {
                        ws = existing
                    } else {
                        ws = WheelSet(
                            id: wsBackup.id,
                            name: wsBackup.name,
                            tireSize: wsBackup.tireSize,
                            tireSeasonRaw: wsBackup.tireSeasonRaw,
                            winterTireKindRaw: wsBackup.winterTireKindRaw,
                            rimTypeRaw: wsBackup.rimTypeRaw,
                            rimDiameterInches: wsBackup.rimDiameterInches,
                            rimWidthInches: wsBackup.rimWidthInches,
                            rimOffsetET: wsBackup.rimOffsetET,
                            rimSpec: wsBackup.rimSpec,
                            createdAt: wsBackup.createdAt,
                            vehicle: vehicle
                        )
                        modelContext.insert(ws)
                    }

                    ws.name = wsBackup.name
                    ws.tireSize = wsBackup.tireSize
                    ws.tireSeasonRaw = wsBackup.tireSeasonRaw
                    ws.winterTireKindRaw = wsBackup.winterTireKindRaw
                    ws.rimTypeRaw = wsBackup.rimTypeRaw
                    ws.rimDiameterInches = wsBackup.rimDiameterInches
                    ws.rimWidthInches = wsBackup.rimWidthInches
                    ws.rimOffsetET = wsBackup.rimOffsetET
                    ws.rimSpec = wsBackup.rimSpec
                    ws.createdAt = wsBackup.createdAt
                    ws.vehicle = vehicle

                    if !vehicle.wheelSets.contains(where: { $0.id == ws.id }) {
                        vehicle.wheelSets.append(ws)
                    }
                }

                vehicle.currentWheelSetID = vehicleBackup.currentWheelSetID
            }
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

                entry.setServiceChecklistItems(entryBackup.serviceChecklistItems ?? [])

                if let ids = entryBackup.maintenanceIntervalIDs, !ids.isEmpty {
                    entry.setLinkedMaintenanceIntervals(ids)
                } else if let id = entryBackup.maintenanceIntervalID {
                    entry.setLinkedMaintenanceIntervals([id])
                } else {
                    entry.setLinkedMaintenanceIntervals([])
                }

                entry.purchaseCategory = entryBackup.purchaseCategory
                entry.purchaseVendor = entryBackup.purchaseVendor

                if formatVersion >= 7 {
                    let items = (entryBackup.purchaseItems ?? []).map {
                        LogEntry.PurchaseItem(title: $0.title, price: $0.price)
                    }
                    entry.setPurchaseItems(items)
                }
                
                entry.tollZone = entryBackup.tollZone
                entry.carwashLocation = entryBackup.carwashLocation
                entry.parkingLocation = entryBackup.parkingLocation
                entry.finesViolationType = entryBackup.finesViolationType

                if formatVersion >= 5 {
                    entry.wheelSetID = entryBackup.wheelSetID
                }

                entry.vehicle = vehicle
                entriesUpserted += 1

                // Attachments (best-effort): do not delete existing ones when backup has none.
                if let backups = entryBackup.attachments {
                    let unique = Dictionary(backups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                    for ab in unique.values {
                        let att: Attachment
                        let id = ab.id
                        let fetch = FetchDescriptor<Attachment>(predicate: #Predicate { $0.id == id })
                        if let existing = try modelContext.fetch(fetch).first {
                            att = existing
                        } else {
                            // Create placeholder; relativePath will be set below.
                            att = Attachment(
                                id: ab.id,
                                createdAt: ab.createdAt,
                                originalFileName: ab.originalFileName,
                                uti: ab.uti,
                                relativePath: "",
                                fileSizeBytes: ab.fileSizeBytes,
                                logEntry: entry
                            )
                            modelContext.insert(att)
                            entry.attachments.append(att)
                        }

                        att.createdAt = ab.createdAt
                        att.originalFileName = ab.originalFileName
                        att.uti = ab.uti
                        att.fileSizeBytes = ab.fileSizeBytes
                        att.logEntry = entry

                        // Attachment-to-interval mapping.
                        // Backward compatible:
                        // - If `appliesToAllMaintenanceIntervals` is missing, treat nil/empty as "all".
                        // - If intervals array is present and non-empty, treat as explicit subset.
                        if let applies = ab.appliesToAllMaintenanceIntervals {
                            if applies {
                                att.setAppliesToAllMaintenanceIntervals()
                            } else {
                                att.setScopedMaintenanceIntervals(ab.maintenanceIntervalIDs ?? [])
                            }
                        } else if let ids = ab.maintenanceIntervalIDs, !ids.isEmpty {
                            att.setScopedMaintenanceIntervals(ids)
                        } else {
                            att.setAppliesToAllMaintenanceIntervals()
                        }

                        // If we already have a file path, keep it; otherwise try restoring from base64.
                        if att.relativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           let b64 = ab.dataBase64 {
                            let rel = try AttachmentsStore.writeBase64(b64, preferredExtension: ab.fileExtension)
                            att.relativePath = rel
                        }
                    }
                }
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
                        templateID: intervalBackup.templateID,
                        intervalKm: intervalBackup.intervalKm,
                        intervalMonths: intervalBackup.intervalMonths,
                        lastDoneDate: intervalBackup.lastDoneDate,
                        lastDoneOdometerKm: intervalBackup.lastDoneOdometerKm,
                        notificationsEnabled: intervalBackup.notificationsEnabled,
                        notificationsByDateEnabled: intervalBackup.notificationsByDateEnabled,
                        notificationsByMileageEnabled: intervalBackup.notificationsByMileageEnabled,
                        notificationLeadDays: intervalBackup.notificationLeadDays,
                        notificationLeadKm: intervalBackup.notificationLeadKm,
                        notificationTimeMinutes: intervalBackup.notificationTimeMinutes,
                        notificationRepeat: MaintenanceNotificationRepeat(rawValue: intervalBackup.notificationRepeatRaw) ?? .none,
                        notes: intervalBackup.notes,
                        isEnabled: intervalBackup.isEnabled,
                        vehicle: vehicle
                    )
                    modelContext.insert(interval)
                }
                
                interval.title = intervalBackup.title
                interval.templateID = intervalBackup.templateID
                interval.intervalKm = intervalBackup.intervalKm
                interval.intervalMonths = intervalBackup.intervalMonths
                interval.lastDoneDate = intervalBackup.lastDoneDate
                interval.lastDoneOdometerKm = intervalBackup.lastDoneOdometerKm
                interval.notificationsEnabled = intervalBackup.notificationsEnabled
                interval.notificationsByDateEnabled = intervalBackup.notificationsByDateEnabled
                interval.notificationsByMileageEnabled = intervalBackup.notificationsByMileageEnabled
                interval.notificationLeadDays = intervalBackup.notificationLeadDays
                interval.notificationLeadKm = intervalBackup.notificationLeadKm
                interval.notificationTimeMinutes = intervalBackup.notificationTimeMinutes
                interval.notificationRepeatRaw = intervalBackup.notificationRepeatRaw
                interval.notes = intervalBackup.notes
                interval.isEnabled = intervalBackup.isEnabled
                interval.vehicle = vehicle
                maintenanceIntervalsUpserted += 1
            }

            let uniqueServiceBookEntries = Dictionary(vehicleBackup.serviceBookEntries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for entryBackup in uniqueServiceBookEntries.values {
                let entry: ServiceBookEntry
                let entryID = entryBackup.id
                let fetch = FetchDescriptor<ServiceBookEntry>(predicate: #Predicate { $0.id == entryID })
                if let existing = try modelContext.fetch(fetch).first {
                    entry = existing
                } else {
                    let performedBy = ServiceBookPerformedBy(rawValue: entryBackup.performedByRaw) ?? .service
                    entry = ServiceBookEntry(
                        id: entryBackup.id,
                        intervalID: entryBackup.intervalID,
                        title: entryBackup.title,
                        date: entryBackup.date,
                        odometerKm: entryBackup.odometerKm,
                        performedBy: performedBy,
                        serviceName: entryBackup.serviceName,
                        oilBrand: entryBackup.oilBrand,
                        oilViscosity: entryBackup.oilViscosity,
                        oilSpec: entryBackup.oilSpec,
                        notes: entryBackup.notes,
                        vehicle: vehicle
                    )
                    modelContext.insert(entry)
                }

                entry.intervalID = entryBackup.intervalID
                entry.title = entryBackup.title
                entry.date = entryBackup.date
                entry.odometerKm = entryBackup.odometerKm
                entry.performedByRaw = entryBackup.performedByRaw
                entry.serviceName = entryBackup.serviceName
                entry.oilBrand = entryBackup.oilBrand
                entry.oilViscosity = entryBackup.oilViscosity
                entry.oilSpec = entryBackup.oilSpec
                entry.notes = entryBackup.notes
                entry.vehicle = vehicle
                serviceBookEntriesUpserted += 1
            }
        }

        try modelContext.save()
        return ImportSummary(
            vehiclesUpserted: vehiclesUpserted, 
            entriesUpserted: entriesUpserted,
            maintenanceIntervalsUpserted: maintenanceIntervalsUpserted,
            serviceBookEntriesUpserted: serviceBookEntriesUpserted
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
