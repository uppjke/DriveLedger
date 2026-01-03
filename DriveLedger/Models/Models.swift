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

    @Relationship(deleteRule: .cascade)
    var wheelSets: [WheelSet] = []

    /// Currently installed wheel set (if known).
    var currentWheelSetID: UUID?

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
        initialOdometerKm: Int? = nil,
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
        self.currentWheelSetID = currentWheelSetID
    }

    var displaySubtitle: String {
        let parts = [make, model]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    var hasExtraDetails: Bool {
        let stringParts: [String?] = [generation, engine, bodyStyle, colorName, licensePlate, vin]
        let hasNonEmptyString = stringParts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains(where: { !$0.isEmpty })

        return hasNonEmptyString || year != nil || initialOdometerKm != nil || currentWheelSet != nil
    }

    var currentWheelSet: WheelSet? {
        guard let id = currentWheelSetID else { return nil }
        return wheelSets.first(where: { $0.id == id })
    }
}

struct WheelSpec: Codable, Identifiable, Hashable {
    var id: UUID = UUID()

    // Tire
    var tireManufacturer: String
    var tireModel: String?
    var tireSeason: TireSeason?
    /// Only meaningful for winter tires.
    var tireStudded: Bool?
    var tireWidthMM: Int
    var tireProfile: Int
    var tireDiameterInches: Int
    var tireSpeedIndex: String?
    var tireLoadIndex: String?
    var tireProductionYear: Int?

    // Rim
    var rimManufacturer: String
    var rimModel: String?
    var rimDiameterInches: Int
    var rimType: RimType?
    var rimWidthInches: Double?
    var rimOffsetET: Int?
    var rimCenterBoreMM: Double?
    var rimBoltPattern: String?

    var diameterLabel: String { "R\(tireDiameterInches)" }

    var tireDisplay: String {
        var parts: [String] = []
        parts.append("\(tireWidthMM)/\(tireProfile) \(diameterLabel)")
        parts.append(tireManufacturer)
        if let m = tireModel?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            parts.append(m)
        }
        if let season = tireSeason {
            parts.append(season.title)
        }
        if tireSeason == .winter, let studded = tireStudded {
            parts.append(studded ? String(localized: "wheelSet.tireStuds.studded") : String(localized: "wheelSet.tireStuds.nonStudded"))
        }
        if let li = tireLoadIndex?.trimmingCharacters(in: .whitespacesAndNewlines), !li.isEmpty {
            parts.append(li)
        }
        if let si = tireSpeedIndex?.trimmingCharacters(in: .whitespacesAndNewlines), !si.isEmpty {
            parts.append(si)
        }
        if let y = tireProductionYear {
            parts.append(String(y))
        }
        return parts.joined(separator: " · ")
    }

    var rimDisplay: String {
        var parts: [String] = []
        parts.append("R\(rimDiameterInches)")
        parts.append(rimManufacturer)
        if let m = rimModel?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            parts.append(m)
        }
        if let t = rimType {
            parts.append(t.title)
        }
        if let w = rimWidthInches {
            let isInt = abs(w.rounded() - w) < 0.000_001
            parts.append(isInt ? String(Int(w.rounded())) : String(format: "%.1f", w))
        }
        if let et = rimOffsetET {
            parts.append("ET\(et)")
        }
        if let dia = rimCenterBoreMM {
            let isInt = abs(dia.rounded() - dia) < 0.000_001
            parts.append(isInt ? "DIA \(Int(dia.rounded()))" : String(format: "DIA %.1f", dia))
        }
        if let pcd = rimBoltPattern?.trimmingCharacters(in: .whitespacesAndNewlines), !pcd.isEmpty {
            parts.append(pcd)
        }
        return parts.joined(separator: " · ")
    }
}

extension WheelSpec {
    /// A stable, content-based key for deduping (ignores `id`).
    var dedupKey: String {
        func norm(_ s: String?) -> String {
            (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        func normDouble(_ v: Double?) -> String {
            guard let v else { return "" }
            let isInt = abs(v.rounded() - v) < 0.000_001
            return isInt ? String(Int(v.rounded())) : String(format: "%.1f", v)
        }

        var parts: [String] = []
        parts.reserveCapacity(20)

        parts.append(norm(tireManufacturer))
        parts.append(norm(tireModel))
        parts.append(tireSeason?.rawValue ?? "")
        parts.append((tireStudded == true) ? "1" : (tireStudded == false ? "0" : ""))
        parts.append(String(tireWidthMM))
        parts.append(String(tireProfile))
        parts.append(String(tireDiameterInches))
        parts.append(norm(tireSpeedIndex))
        parts.append(norm(tireLoadIndex))
        parts.append(tireProductionYear.map(String.init) ?? "")

        parts.append(norm(rimManufacturer))
        parts.append(norm(rimModel))
        parts.append(String(rimDiameterInches))
        parts.append(rimType?.rawValue ?? "")
        parts.append(normDouble(rimWidthInches))
        parts.append(rimOffsetET.map(String.init) ?? "")
        parts.append(normDouble(rimCenterBoreMM))
        parts.append(norm(rimBoltPattern))

        return parts.joined(separator: "|")
    }
}

@Model
final class WheelSet: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Optional tire size string (e.g. "205/55 R16").
    var tireSize: String?

    // MARK: - Tire specs (v9+)
    /// Required for new wheel sets (UI enforces): tire manufacturer.
    var tireManufacturer: String?
    /// Required for new wheel sets (UI enforces): tire model.
    var tireModel: String?
    /// Required for new wheel sets (UI enforces): tire width in mm.
    var tireWidthMM: Int?
    /// Required for new wheel sets (UI enforces): tire profile in %.
    var tireProfile: Int?
    /// Required for new wheel sets (UI enforces): tire diameter in inches (R).
    var tireDiameterInches: Int?
    /// Optional (e.g. "V", "H", "W").
    var tireSpeedIndex: String?
    /// For winter tires: whether the tire is studded. Required in UI when season == winter.
    var tireStudded: Bool?
    /// Number of tires described by this set (2 or 4); UI defaults to 4.
    var tireCount: Int?
    /// Per-tire production years, stored as JSON array for SwiftData compatibility.
    var tireProductionYearsJSON: String = "[]"

    /// Per-wheel specs (up to 4), stored as JSON array for SwiftData compatibility.
    var wheelSpecsJSON: String = "[]"

    // MARK: - Rim specs (v9+)
    /// Required for new wheel sets (UI enforces): rim manufacturer.
    var rimManufacturer: String?
    /// Required for new wheel sets (UI enforces): rim model.
    var rimModel: String?
    /// Optional bolt pattern (PCD), e.g. "5x114.3".
    var rimBoltPattern: String?
    /// Optional center bore diameter (DIA) in mm.
    var rimCenterBoreMM: Double?

    /// Seasonality of the tire set.
    var tireSeasonRaw: String?
    /// For winter tires: studded vs friction.
    var winterTireKindRaw: String?

    /// Optional rim type (alloy/steel).
    var rimTypeRaw: String?

    /// Structured rim specs (preferred when present).
    var rimDiameterInches: Int?
    var rimWidthInches: Double?
    var rimOffsetET: Int?
    /// Optional rim spec string (e.g. "16x6.5 ET45").
    var rimSpec: String?
    var createdAt: Date

    @Relationship(inverse: \Vehicle.wheelSets)
    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        name: String,
        tireSize: String? = nil,
        tireSeasonRaw: String? = nil,
        winterTireKindRaw: String? = nil,
        rimTypeRaw: String? = nil,
        rimDiameterInches: Int? = nil,
        rimWidthInches: Double? = nil,
        rimOffsetET: Int? = nil,
        rimSpec: String? = nil,
        createdAt: Date = Date(),
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.name = name
        self.tireSize = tireSize
        self.tireSeasonRaw = tireSeasonRaw
        self.winterTireKindRaw = winterTireKindRaw
        self.rimTypeRaw = rimTypeRaw
        self.rimDiameterInches = rimDiameterInches
        self.rimWidthInches = rimWidthInches
        self.rimOffsetET = rimOffsetET
        self.rimSpec = rimSpec
        self.createdAt = createdAt
        self.vehicle = vehicle
    }

    var tireSeason: TireSeason? {
        get { tireSeasonRaw.flatMap(TireSeason.init(rawValue:)) }
        set { tireSeasonRaw = newValue?.rawValue }
    }

    var winterTireKind: WinterTireKind? {
        get { winterTireKindRaw.flatMap(WinterTireKind.init(rawValue:)) }
        set { winterTireKindRaw = newValue?.rawValue }
    }

    var rimType: RimType? {
        get {
            guard let raw = rimTypeRaw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
            // Legacy mapping: "steel" -> stamped.
            if raw == "steel" { return .stamped }
            return RimType(rawValue: raw)
        }
        set { rimTypeRaw = newValue?.rawValue }
    }

    var tireProductionYears: [Int?] {
        get {
            guard let data = tireProductionYearsJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([Int?].self, from: data)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(newValue),
               let s = String(data: data, encoding: .utf8) {
                tireProductionYearsJSON = s
            } else {
                tireProductionYearsJSON = "[]"
            }
        }
    }

    var wheelSpecs: [WheelSpec] {
        get {
            guard let data = wheelSpecsJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([WheelSpec].self, from: data)) ?? []
        }
        set {
            let capped = Array(newValue.prefix(4))
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(capped),
               let s = String(data: data, encoding: .utf8) {
                wheelSpecsJSON = s
            } else {
                wheelSpecsJSON = "[]"
            }
        }
    }

    private var formattedTireSpec: String? {
        var parts: [String] = []

        let sizeFromParts: String? = {
            if let w = tireWidthMM, let p = tireProfile, let d = tireDiameterInches {
                return "\(w)/\(p) R\(d)"
            }
            let legacy = tireSize?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return legacy.isEmpty ? nil : legacy
        }()

        if let size = sizeFromParts { parts.append(size) }

        let brand = tireManufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = tireModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let brandModel = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        if !brandModel.isEmpty {
            parts.append(brandModel)
        }

        if let season = tireSeason {
            parts.append(season.title)
            if season == .winter {
                if let studs = tireStudded {
                    parts.append(studs ? String(localized: "wheelSet.tireStuds.studded") : String(localized: "wheelSet.tireStuds.nonStudded"))
                } else if let wk = winterTireKind {
                    // Legacy fallback.
                    parts.append(wk.title)
                }
            }
        }

        if let siRaw = tireSpeedIndex, let si = TextParsing.cleanOptional(siRaw) {
            parts.append(si.uppercased())
        }

        let joined = parts.joined(separator: " · ")
        return joined.isEmpty ? nil : joined
    }

    private var formattedRimSpec: String? {
        var parts: [String] = []

        let rBrand = rimManufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rModel = rimModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rm = [rBrand, rModel].filter { !$0.isEmpty }.joined(separator: " ")
        if !rm.isEmpty {
            parts.append(rm)
        }

        if let type = rimType {
            parts.append(type.title)
        }

        if let d = rimDiameterInches {
            parts.append("R\(d)")
        }

        if let w = rimWidthInches {
            let isInt = abs(w.rounded() - w) < 0.000_001
            let wText = isInt ? String(Int(w.rounded())) : String(format: "%.1f", w)
            parts.append("\(wText)J")
        }

        if let et = rimOffsetET {
            parts.append("ET\(et)")
        }

        if let pcdRaw = rimBoltPattern, let pcd = TextParsing.cleanOptional(pcdRaw) {
            parts.append("PCD \(pcd)")
        }

        if let dia = rimCenterBoreMM {
            let isInt = abs(dia.rounded() - dia) < 0.000_001
            let t = isInt ? String(Int(dia.rounded())) : String(format: "%.1f", dia)
            parts.append("DIA \(t)")
        }

        let computed = parts.joined(separator: " ")
        if !computed.isEmpty {
            return computed
        }

        let legacy = rimSpec?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return legacy.isEmpty ? nil : legacy
    }

    var summary: String {
        let parts = [formattedTireSpec, formattedRimSpec]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }
}

enum TireSeason: String, Codable, CaseIterable, Identifiable {
    case summer, winter, allSeason
    var id: String { rawValue }

    var title: String {
        switch self {
        case .summer:
            return String(localized: "wheelSet.tireSeason.summer")
        case .winter:
            return String(localized: "wheelSet.tireSeason.winter")
        case .allSeason:
            return String(localized: "wheelSet.tireSeason.allSeason")
        }
    }
}

enum WinterTireKind: String, Codable, CaseIterable, Identifiable {
    case studded, friction
    var id: String { rawValue }

    var title: String {
        switch self {
        case .studded:
            return String(localized: "wheelSet.winterKind.studded")
        case .friction:
            return String(localized: "wheelSet.winterKind.friction")
        }
    }
}

enum RimType: String, Codable, CaseIterable, Identifiable {
    case stamped, alloy, forged
    var id: String { rawValue }

    var title: String {
        switch self {
        case .stamped:
            return String(localized: "wheelSet.rimType.stamped")
        case .alloy:
            return String(localized: "wheelSet.rimType.alloy")
        case .forged:
            return String(localized: "wheelSet.rimType.forged")
        }
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

    /// Optional wheel set reference (primarily for tire service entries).
    var wheelSetID: UUID?

    /// Optional link to a maintenance interval (service book).
    var maintenanceIntervalID: UUID?

    /// Optional links to multiple maintenance intervals (service book).
    /// Backward compatible with `maintenanceIntervalID`.
    /// Stored as JSON array of UUID strings for maximum SwiftData compatibility.
    var maintenanceIntervalIDsJSON: String = "[]"

    /// Service work checklist items (stored as JSON array of strings).
    var serviceChecklistJSON: String = "[]"

    /// Purchase items with optional per-item price (stored as JSON array).
    var purchaseItemsJSON: String = "[]"

    @Relationship(deleteRule: .cascade)
    var attachments: [Attachment] = []

    var purchaseCategory: String?
    var purchaseVendor: String?
    
    // Category-specific extended fields
    var tollZone: String?           // Legacy: Для платных дорог: зона/участок

    // Платные дороги: трасса + начало/конец (для заголовка и отображения)
    var tollRoad: String?
    var tollStart: String?
    var tollEnd: String?
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

    var tollDisplayTitle: String {
        let road = TextParsing.cleanOptional(tollRoad ?? "") ?? TextParsing.cleanOptional(tollZone ?? "")
        let start = TextParsing.cleanOptional(tollStart ?? "")
        let end = TextParsing.cleanOptional(tollEnd ?? "")

        guard let road else { return String(localized: "entry.kind.tolls") }

        if let start, let end { return "\(road): \(start) - \(end)" }
        if let start { return "\(road): \(start)" }
        if let end { return "\(road): \(end)" }
        return road
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

    var serviceChecklistItems: [String] {
        guard let data = serviceChecklistJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    func setServiceChecklistItems(_ items: [String]) {
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let data = try? JSONEncoder().encode(cleaned),
           let s = String(data: data, encoding: .utf8) {
            serviceChecklistJSON = s
        } else {
            serviceChecklistJSON = "[]"
        }
    }

    struct PurchaseItem: Codable, Equatable {
        var title: String
        var price: Double?
    }

    var purchaseItems: [PurchaseItem] {
        guard let data = purchaseItemsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([PurchaseItem].self, from: data)) ?? []
    }

    func setPurchaseItems(_ items: [PurchaseItem]) {
        let cleaned: [PurchaseItem] = items.compactMap { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return PurchaseItem(title: title, price: item.price)
        }

        if let data = try? JSONEncoder().encode(cleaned),
           let s = String(data: data, encoding: .utf8) {
            purchaseItemsJSON = s
        } else {
            purchaseItemsJSON = "[]"
        }
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
final class Attachment: Identifiable {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    /// Original file name (as picked by user), for display.
    var originalFileName: String
    /// Uniform Type Identifier string (e.g. "com.adobe.pdf", "public.jpeg").
    var uti: String
    /// Relative path under app container (e.g. "Attachments/<uuid>.pdf").
    var relativePath: String
    /// File size in bytes (optional; best effort).
    var fileSizeBytes: Int?

    /// Optional mapping: which maintenance intervals this attachment relates to.
    /// Stored as JSON array of UUID strings for maximum SwiftData compatibility.
    /// Used together with `appliesToAllMaintenanceIntervals`.
    /// When `appliesToAllMaintenanceIntervals == true`, this list is ignored.
    var maintenanceIntervalIDsJSON: String = "[]"

    /// Controls how `maintenanceIntervalIDsJSON` should be interpreted.
    /// Default is `true` for backward compatibility: existing attachments apply to all linked intervals.
    /// When `false`, `maintenanceIntervalIDsJSON` contains an explicit list (which may be empty, meaning "none").
    var appliesToAllMaintenanceIntervals: Bool = true

    @Relationship(inverse: \LogEntry.attachments)
    var logEntry: LogEntry?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        originalFileName: String,
        uti: String,
        relativePath: String,
        fileSizeBytes: Int? = nil,
        logEntry: LogEntry? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.originalFileName = originalFileName
        self.uti = uti
        self.relativePath = relativePath
        self.fileSizeBytes = fileSizeBytes
        self.logEntry = logEntry
    }

    /// Explicit list of maintenance intervals this attachment should be shown for.
    /// Only meaningful when `appliesToAllMaintenanceIntervals == false`.
    var scopedMaintenanceIntervalIDs: [UUID] {
        guard let raw = maintenanceIntervalIDStringsFromJSON(), !raw.isEmpty else { return [] }
        return raw.compactMap(UUID.init(uuidString:))
    }

    /// Switch to "all linked intervals" mode.
    func setAppliesToAllMaintenanceIntervals() {
        appliesToAllMaintenanceIntervals = true
        // Keep JSON compact for storage/backup diff friendliness.
        maintenanceIntervalIDsJSON = "[]"
    }

    /// Switch to explicit scope mode.
    /// `ids` may be empty, meaning "doesn't relate to any interval".
    func setScopedMaintenanceIntervals(_ ids: [UUID]) {
        appliesToAllMaintenanceIntervals = false
        let unique = Array(Set(ids))
        setMaintenanceIntervalIDStringsJSON(unique.map { $0.uuidString })
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
