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
    case fuel, service, purchase, odometer, note
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuel: return "Заправка"
        case .service: return "Обслуживание"
        case .purchase: return "Покупка"
        case .odometer: return "Пробег"
        case .note: return "Заметка"
        }
    }

    var systemImage: String {
        switch self {
        case .fuel: return "fuelpump"
        case .service: return "wrench.and.screwdriver"
        case .purchase: return "cart"
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
    var year: Int?
    var createdAt: Date
    /// Пробег на момент добавления автомобиля (опционально)
    var initialOdometerKm: Int?

    @Relationship(deleteRule: .cascade)
    var entries: [LogEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        make: String? = nil,
        model: String? = nil,
        year: Int? = nil,
        createdAt: Date = Date(),
        initialOdometerKm: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.make = make
        self.model = model
        self.year = year
        self.createdAt = createdAt
        self.initialOdometerKm = initialOdometerKm
    }

    var displaySubtitle: String {
        let parts = [make, model, year.map(String.init)]
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

