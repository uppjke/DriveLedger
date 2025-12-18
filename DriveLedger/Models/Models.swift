//
//  Models.swift
//  DriveLedger
//

import Foundation
import SwiftData

enum FuelFillKind: String, Codable, CaseIterable, Identifiable {
    case full, partial
    var id: String { rawValue }
    var title: String { self == .full ? "Полный бак" : "Долив" }
}

enum LogEntryKind: String, Codable, CaseIterable, Identifiable {
    case fuel, service, purchase, tolls, fines, carwash, parking, odometer, note
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuel: return "Заправка"
        case .service: return "Обслуживание"
        case .purchase: return "Покупка"
        case .tolls: return String(localized: "entry.kind.tolls")
        case .fines: return String(localized: "entry.kind.fines")
        case .carwash: return String(localized: "entry.kind.carwash")
        case .parking: return String(localized: "entry.kind.parking")
        case .odometer: return "Пробег"
        case .note: return "Заметка"
        }
    }

    var systemImage: String {
        switch self {
        case .fuel: return "fuelpump"
        case .service: return "wrench.and.screwdriver"
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
    /// Optional SF Symbol name representing the vehicle (e.g. "car.fill").
    var iconSymbol: String?
    /// Пробег на момент добавления автомобиля (опционально)
    var initialOdometerKm: Int?

    @Relationship(deleteRule: .cascade)
    var entries: [LogEntry] = []

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

    var purchaseCategory: String?
    var purchaseVendor: String?

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

    var fuelFillKind: FuelFillKind {
        get { FuelFillKind(rawValue: fuelFillKindRaw ?? "") ?? .full } // backwards-compatible default
        set { fuelFillKindRaw = newValue.rawValue }
    }
}

