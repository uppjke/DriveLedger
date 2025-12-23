//
//  Models.swift
//  DriveLedger
//

import Foundation
import SwiftData

enum FuelFillKind: String, Codable, CaseIterable, Identifiable {
    case full, partial
    var id: String { rawValue }
    var title: String {
        switch self {
        case .full: return String(localized: "fuel.fillKind.full")
        case .partial: return String(localized: "fuel.fillKind.partial")
        }
    }
}

enum LogEntryKind: String, Codable, CaseIterable, Identifiable {
    case fuel, service, tireService, purchase, tolls, fines, carwash, parking, odometer, note
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuel: return String(localized: "entry.kind.fuel")
        case .service: return String(localized: "entry.kind.service")
        case .tireService: return String(localized: "entry.kind.tireService")
        case .purchase: return String(localized: "entry.kind.purchase")
        case .tolls: return String(localized: "entry.kind.tolls")
        case .fines: return String(localized: "entry.kind.fines")
        case .carwash: return String(localized: "entry.kind.carwash")
        case .parking: return String(localized: "entry.kind.parking")
        case .odometer: return String(localized: "entry.kind.odometer")
        case .note: return String(localized: "entry.kind.note")
        }
    }

    var systemImage: String {
        switch self {
        case .fuel: return "fuelpump"
        case .service: return "wrench.and.screwdriver"
        case .tireService: return "tire"
        case .purchase: return "cart"
        case .tolls: return "road.lanes"
        case .fines: return "exclamationmark.triangle"
        case .carwash: return "drop"
        case .parking: return "parkingsign.circle"
        case .odometer: return "speedometer"
        case .note: return "note.text"
        }
    }
}

@Model
final class Vehicle: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var make: String?
    var model: String?
    /// Optional generation/series label (e.g. "XV70", "E90", "I", "рестайлинг").
    var generation: String?
    var year: Int?
    /// Optional engine descriptor (e.g. "1.6 106 л.с.", "2.0T", "EV").
    var engine: String?
    /// Optional body style identifier (e.g. "sedan", "suv").
    var bodyStyle: String?
    /// Optional body color (stored as a stable identifier, e.g. "white", "black").
    var colorName: String?
    var createdAt: Date
    /// Optional license plate / registration number.
    var licensePlate: String?
    /// Optional VIN (Vehicle Identification Number).
    var vin: String?
    /// Optional SF Symbol name representing the vehicle (e.g. "car.fill").
    var iconSymbol: String?
    /// Пробег на момент добавления автомобиля (опционально)
    var initialOdometerKm: Int?

    @Relationship(deleteRule: .cascade)
    var entries: [LogEntry] = []
    
    @Relationship(deleteRule: .cascade)
    var maintenanceIntervals: [MaintenanceInterval] = []

    @Relationship(deleteRule: .cascade)
    var serviceBookEntries: [ServiceBookEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        make: String? = nil,
        model: String? = nil,
        generation: String? = nil,
        year: Int? = nil,
        engine: String? = nil,
        bodyStyle: String? = nil,
        colorName: String? = nil,
        createdAt: Date = Date(),
        licensePlate: String? = nil,
        vin: String? = nil,
        iconSymbol: String? = nil,
        initialOdometerKm: Int? = nil
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
    }

    var displaySubtitle: String {
        let parts = [make, model, generation, engine, year.map(String.init)]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }
}

enum ServiceBookPerformedBy: String, Codable, CaseIterable, Identifiable {
    case service, diy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .service:
            return String(localized: "serviceBook.performedBy.service")
        case .diy:
            return String(localized: "serviceBook.performedBy.diy")
        }
    }
}

enum MaintenanceNotificationRepeat: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return String(localized: "maintenance.notifications.repeat.none")
        case .daily:
            return String(localized: "maintenance.notifications.repeat.daily")
        case .weekly:
            return String(localized: "maintenance.notifications.repeat.weekly")
        }
    }
}

@Model
final class LogEntry: Identifiable {
    @Attribute(.unique) var id: UUID

    var kindRaw: String
    var date: Date
    /// Пробег (может быть не указан)
    var odometerKm: Int?

    var totalCost: Double?
    var notes: String?

    var fuelLiters: Double?
    var fuelPricePerLiter: Double?
    var fuelStation: String?
    /// Расход (л/100км), если получилось посчитать
    var fuelConsumptionLPer100km: Double?

    /// Полный бак / долив (для корректного расчёта расхода)
    var fuelFillKindRaw: String?

    var serviceTitle: String?
    var serviceDetails: String?

    /// Optional link to a maintenance interval (service book).
    var maintenanceIntervalID: UUID?

    /// Optional links to multiple maintenance intervals (service book).
    /// Backward compatible with `maintenanceIntervalID`.
    /// Stored as JSON array of UUID strings for maximum SwiftData compatibility.
    var maintenanceIntervalIDsJSON: String = "[]"

    var purchaseCategory: String?
    var purchaseVendor: String?
    
    // Category-specific extended fields
    var tollZone: String?           // Для платных дорог: зона/участок
    var carwashLocation: String?    // Для мойки: название/место
    var parkingLocation: String?    // Для парковки: адрес/название
    var finesViolationType: String? // Для штрафов: тип нарушения

    @Relationship(inverse: \Vehicle.entries)
    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        kind: LogEntryKind,
        date: Date = Date(),
        odometerKm: Int? = nil,
        totalCost: Double? = nil,
        notes: String? = nil,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.date = date
        self.odometerKm = odometerKm
        self.totalCost = totalCost
        self.notes = notes
        self.vehicle = vehicle
    }

    var kind: LogEntryKind {
        get { LogEntryKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    /// Effective linked maintenance interval IDs.
    /// Uses `maintenanceIntervalIDs` when present, otherwise falls back to legacy `maintenanceIntervalID`.
    var linkedMaintenanceIntervalIDs: [UUID] {
        if let raw = maintenanceIntervalIDStringsFromJSON(), !raw.isEmpty {
            let ids = raw.compactMap(UUID.init(uuidString:))
            if !ids.isEmpty { return ids }
        }
        if let id = maintenanceIntervalID {
            return [id]
        }
        return []
    }

    func setLinkedMaintenanceIntervals(_ ids: [UUID]) {
        let unique = Array(Set(ids))
        setMaintenanceIntervalIDStringsJSON(unique.map { $0.uuidString })
        maintenanceIntervalID = (unique.count == 1) ? unique.first : nil
    }

    private func maintenanceIntervalIDStringsFromJSON() -> [String]? {
        guard let data = maintenanceIntervalIDsJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    private func setMaintenanceIntervalIDStringsJSON(_ strings: [String]) {
        if let data = try? JSONEncoder().encode(strings),
           let s = String(data: data, encoding: .utf8) {
            maintenanceIntervalIDsJSON = s
        } else {
            maintenanceIntervalIDsJSON = "[]"
        }
    }
    
    var fuelFillKind: FuelFillKind {
        get { FuelFillKind(rawValue: fuelFillKindRaw ?? "") ?? .full }
        set { fuelFillKindRaw = newValue.rawValue }
    }
}

@Model
final class MaintenanceInterval: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String

    /// Optional template identifier to enable adaptive UI for mark-done details.
    var templateID: String?
    var intervalKm: Int?
    var intervalMonths: Int?
    
    var lastDoneDate: Date?
    var lastDoneOdometerKm: Int?

    /// Whether the user wants a local notification for this reminder.
    /// Note: mileage-based notifications require app-side logic; this flag stores intent.
    var notificationsEnabled: Bool

    /// Fine-grained notification settings.
    var notificationsByDateEnabled: Bool = true
    var notificationsByMileageEnabled: Bool = true
    /// Lead time in days for date-based reminders.
    var notificationLeadDays: Int = 30
    /// Lead distance (km) for mileage-based reminders.
    var notificationLeadKm: Int? = nil
    /// Time of day for notifications, in minutes from midnight.
    var notificationTimeMinutes: Int = 9 * 60
    var notificationRepeatRaw: String = "none"
    
    var notes: String?
    var isEnabled: Bool
    
    @Relationship(inverse: \Vehicle.maintenanceIntervals)
    var vehicle: Vehicle?
    
    init(
        id: UUID = UUID(),
        title: String,
        templateID: String? = nil,
        intervalKm: Int? = nil,
        intervalMonths: Int? = nil,
        lastDoneDate: Date? = nil,
        lastDoneOdometerKm: Int? = nil,
        notificationsEnabled: Bool = false,
        notificationsByDateEnabled: Bool = true,
        notificationsByMileageEnabled: Bool = true,
        notificationLeadDays: Int = 30,
        notificationLeadKm: Int? = nil,
        notificationTimeMinutes: Int = 9 * 60,
        notificationRepeat: MaintenanceNotificationRepeat = .none,
        notes: String? = nil,
        isEnabled: Bool = true,
        vehicle: Vehicle? = nil
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
        self.notificationRepeatRaw = notificationRepeat.rawValue
        self.notes = notes
        self.isEnabled = isEnabled
        self.vehicle = vehicle
    }

    var notificationRepeat: MaintenanceNotificationRepeat {
        get { MaintenanceNotificationRepeat(rawValue: notificationRepeatRaw) ?? .none }
        set { notificationRepeatRaw = newValue.rawValue }
    }
    
    func nextDueKm(currentKm: Int?) -> Int? {
        guard let intervalKm, let lastKm = lastDoneOdometerKm else { return nil }
        return lastKm + intervalKm
    }
    
    func nextDueDate() -> Date? {
        guard let intervalMonths, let lastDate = lastDoneDate else { return nil }
        return Calendar.current.date(byAdding: .month, value: intervalMonths, to: lastDate)
    }
    
    func kmUntilDue(currentKm: Int?) -> Int? {
        guard let currentKm, let nextKm = nextDueKm(currentKm: currentKm) else { return nil }
        return nextKm - currentKm
    }

    func daysUntilDue() -> Int? {
        guard let nextDate = nextDueDate() else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day
    }
    
    enum Status {
        case ok, warning, overdue, unknown
    }
    
    func status(currentKm: Int?) -> Status {
        guard isEnabled else { return .unknown }

        func kmStatus() -> Status? {
            guard let kmLeft = kmUntilDue(currentKm: currentKm), let intervalKm else { return nil }
            if kmLeft < 0 { return .overdue }
            if kmLeft <= max(1, intervalKm / 5) { return .warning } // <= 20% left
            return .ok
        }

        func daysStatus() -> Status? {
            guard let daysLeft = daysUntilDue() else { return nil }
            if daysLeft < 0 { return .overdue }
            if daysLeft <= 30 { return .warning }
            return .ok
        }

        let parts = [kmStatus(), daysStatus()].compactMap { $0 }
        guard !parts.isEmpty else { return .unknown }

        // If either limit is close/overdue, treat the task as close/overdue.
        if parts.contains(.overdue) { return .overdue }
        if parts.contains(.warning) { return .warning }
        return .ok
    }
}

@Model
final class ServiceBookEntry: Identifiable {
    @Attribute(.unique) var id: UUID

    /// Which reminder this record belongs to.
    var intervalID: UUID
    /// Display title at time of record creation.
    var title: String
    var date: Date
    var odometerKm: Int?

    var performedByRaw: String
    var serviceName: String?

    // Adaptive details (initially: oils). Keep optional and expandable.
    var oilBrand: String?
    var oilViscosity: String?
    var oilSpec: String?

    var notes: String?

    @Relationship(inverse: \Vehicle.serviceBookEntries)
    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        intervalID: UUID,
        title: String,
        date: Date = Date(),
        odometerKm: Int? = nil,
        performedBy: ServiceBookPerformedBy,
        serviceName: String? = nil,
        oilBrand: String? = nil,
        oilViscosity: String? = nil,
        oilSpec: String? = nil,
        notes: String? = nil,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.intervalID = intervalID
        self.title = title
        self.date = date
        self.odometerKm = odometerKm
        self.performedByRaw = performedBy.rawValue
        self.serviceName = serviceName
        self.oilBrand = oilBrand
        self.oilViscosity = oilViscosity
        self.oilSpec = oilSpec
        self.notes = notes
        self.vehicle = vehicle
    }

    var performedBy: ServiceBookPerformedBy {
        get { ServiceBookPerformedBy(rawValue: performedByRaw) ?? .service }
        set { performedByRaw = newValue.rawValue }
    }
}
