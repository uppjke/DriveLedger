//
//  EditEntrySheet.swift
//  DriveLedger
//

import SwiftUI
import Foundation
import SwiftData
import UniformTypeIdentifiers

struct EditEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: LogEntry
    let existingEntries: [LogEntry]

    @State private var kind: LogEntryKind
    @State private var date: Date
    @State private var odometerText: String
    @State private var costText: String
    @State private var notes: String
    @State private var fuelFillKind: FuelFillKind

    @State private var litersText: String
    @State private var pricePerLiterText: String
    @State private var stationChoice: String
    @State private var customStation: String

    @State private var serviceDetails: String

    @State private var maintenanceIntervalIDs: Set<UUID>
    @State private var serviceChecklistItems: [String]

    @State private var tireWheelSetChoice: String
    @State private var newWheelSetName: String

    // Wheel set draft (v9+)
    @State private var newWheelSetTireManufacturer: String
    @State private var newWheelSetTireModel: String
    @State private var newWheelSetTireSeasonRaw: String
    /// -1 = not set, 0 = non-studded, 1 = studded
    @State private var newWheelSetTireStuddedChoice: Int
    @State private var newWheelSetTireWidthText: String
    @State private var newWheelSetTireProfileText: String
    @State private var newWheelSetTireDiameter: Int
    @State private var newWheelSetTireSpeedIndex: String
    @State private var newWheelSetTireCount: Int
    @State private var newWheelSetTireYearTexts: [String]

    @State private var newWheelSetRimManufacturer: String
    @State private var newWheelSetRimModel: String
    @State private var newWheelSetRimTypeRaw: String
    @State private var newWheelSetRimDiameter: Int
    @State private var newWheelSetRimWidth: Double
    @State private var newWheelSetRimOffsetET: Int
    @State private var newWheelSetRimCenterBoreText: String
    @State private var newWheelSetRimBoltPattern: String

    @State private var vendor: String
    @State private var purchaseItems: [LogEntry.PurchaseItem]
    @State private var purchasePriceTexts: [String]

    @State private var purchaseDidUserEditTotalCost: Bool
    @State private var purchaseLastAutoCostText: String
    
    // Extended category-specific fields
    @State private var tollRoad: String
    @State private var tollStart: String
    @State private var tollEnd: String
    @State private var carwashLocation: String
    @State private var parkingLocation: String
    @State private var finesViolationType: String

    @State private var isImportingAttachments = false
    @State private var attachmentImportError: String?

    private var computedServiceTitleFromChecklist: String? {
        TextParsing.buildServiceTitleFromChecklist(serviceChecklistItems)
    }

    private var navigationTitleText: String {
        if kind == .service || kind == .tireService {
            return computedServiceTitleFromChecklist ?? String(localized: "entry.title.edit")
        }
        if kind == .tolls {
            let road = TextParsing.cleanOptional(tollRoad)
            let start = TextParsing.cleanOptional(tollStart)
            let end = TextParsing.cleanOptional(tollEnd)

            if let road {
                if let start, let end { return "\(road): \(start) - \(end)" }
                if let start { return "\(road): \(start)" }
                if let end { return "\(road): \(end)" }
                return road
            }
        }
        return String(localized: "entry.title.edit")
    }

    private static let stationCustomToken = "__custom__"
    private static let wheelSetAddToken = "__addWheelSet__"
    private static let rimOffsetNoneToken = -999
    private let fuelStationPresets: [String] = [
        "Лукойл",
        "Газпромнефть",
        "Роснефть",
        "Татнефть",
        "Teboil"
    ]

    private var sortedWheelSets: [WheelSet] {
        (entry.vehicle?.wheelSets ?? []).sorted { a, b in
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    private var resolvedStation: String {
        if stationChoice == Self.stationCustomToken {
            return customStation
        }
        return stationChoice
    }

    private var shouldShowComputedFuelCostRow: Bool {
        guard kind == .fuel else { return false }
        guard let liters = TextParsing.parseDouble(litersText), liters > 0 else { return false }
        guard let price = TextParsing.parseDouble(pricePerLiterText), price > 0 else { return false }
        return true
    }

    private func isLatestTireServiceEntry(using draftDate: Date) -> Bool {
        WheelSetSelectionLogic.isLatestTireServiceEntry(
            existingEntries: existingEntries,
            entryID: entry.id,
            draftDate: draftDate
        )
    }

    private var isNewWheelSetDraftValid: Bool {
        let tireBrandOk = TextParsing.cleanOptional(newWheelSetTireManufacturer) != nil
        let tireModelOk = TextParsing.cleanOptional(newWheelSetTireModel) != nil
        let seasonOk = !newWheelSetTireSeasonRaw.isEmpty
        let studsOk: Bool = {
            guard TireSeason(rawValue: newWheelSetTireSeasonRaw) == .winter else { return true }
            return newWheelSetTireStuddedChoice == 0 || newWheelSetTireStuddedChoice == 1
        }()
        let wOk = TextParsing.parseIntOptional(newWheelSetTireWidthText) != nil
        let pOk = TextParsing.parseIntOptional(newWheelSetTireProfileText) != nil
        let dOk = newWheelSetTireDiameter != 0

        let rimBrandOk = TextParsing.cleanOptional(newWheelSetRimManufacturer) != nil
        let rimModelOk = TextParsing.cleanOptional(newWheelSetRimModel) != nil
        let rimTypeOk = !newWheelSetRimTypeRaw.isEmpty
        let rimDiameterOk = newWheelSetRimDiameter != 0

        return tireBrandOk && tireModelOk && seasonOk && studsOk && wOk && pOk && dOk && rimBrandOk && rimModelOk && rimTypeOk && rimDiameterOk
    }

    private func normalizedTireSizeString(width: Int?, profile: Int?, diameter: Int?) -> String? {
        guard let w = width, let p = profile, let d = diameter else { return nil }
        return "\(w)/\(p) R\(d)"
    }

    private func applySameYearPresetForNewWheelSet() {
        let visibleCount = (newWheelSetTireCount == 2) ? 2 : 4
        guard visibleCount > 0 else { return }
        let source = newWheelSetTireYearTexts.first ?? ""
        let clean = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        for i in 0..<min(visibleCount, newWheelSetTireYearTexts.count) {
            newWheelSetTireYearTexts[i] = clean
        }
    }

    private func createWheelSetFromDraftIfNeeded() -> WheelSet? {
        guard let vehicle = entry.vehicle else { return nil }

        guard isNewWheelSetDraftValid else { return nil }

        let name = TextParsing.cleanRequired(newWheelSetName, fallback: String(localized: "wheelSet.defaultName"))
        let tireSeasonRaw = newWheelSetTireSeasonRaw.isEmpty ? nil : newWheelSetTireSeasonRaw
        let rimTypeRaw = newWheelSetRimTypeRaw.isEmpty ? nil : newWheelSetRimTypeRaw
        let rimDiameter = newWheelSetRimDiameter == 0 ? nil : newWheelSetRimDiameter
        let rimWidth = newWheelSetRimWidth == 0 ? nil : newWheelSetRimWidth
        let rimOffsetET = newWheelSetRimOffsetET == Self.rimOffsetNoneToken ? nil : newWheelSetRimOffsetET

        let tireWidth = TextParsing.parseIntOptional(newWheelSetTireWidthText)
        let tireProfile = TextParsing.parseIntOptional(newWheelSetTireProfileText)
        let tireDiam = newWheelSetTireDiameter == 0 ? nil : newWheelSetTireDiameter
        let computedTireSize = normalizedTireSizeString(width: tireWidth, profile: tireProfile, diameter: tireDiam)

        let studs: Bool? = {
            guard TireSeason(rawValue: newWheelSetTireSeasonRaw) == .winter else { return nil }
            if newWheelSetTireStuddedChoice == 1 { return true }
            if newWheelSetTireStuddedChoice == 0 { return false }
            return nil
        }()

        let yearCount = (newWheelSetTireCount == 2) ? 2 : 4
        let years: [Int?] = (0..<min(yearCount, newWheelSetTireYearTexts.count)).map { idx in
            TextParsing.parseIntOptional(newWheelSetTireYearTexts[idx])
        }

        let ws = WheelSet(
            name: name,
            tireSeasonRaw: tireSeasonRaw,
            rimTypeRaw: rimTypeRaw,
            rimDiameterInches: rimDiameter,
            rimWidthInches: rimWidth,
            rimOffsetET: rimOffsetET,
            rimSpec: WheelSpecsCatalog.normalizeWheelSetRimSpec(
                rimType: rimTypeRaw.flatMap(RimType.init(rawValue:)),
                diameter: rimDiameter,
                width: rimWidth,
                offsetET: rimOffsetET
            ),
            vehicle: vehicle
        )
        ws.tireManufacturer = TextParsing.cleanOptional(newWheelSetTireManufacturer)
        ws.tireModel = TextParsing.cleanOptional(newWheelSetTireModel)
        ws.tireWidthMM = tireWidth
        ws.tireProfile = tireProfile
        ws.tireDiameterInches = tireDiam
        ws.tireSpeedIndex = TextParsing.cleanOptional(newWheelSetTireSpeedIndex)
        ws.tireStudded = studs
        ws.tireCount = newWheelSetTireCount
        ws.tireProductionYears = years
        ws.tireSize = computedTireSize
        ws.winterTireKindRaw = nil

        ws.rimManufacturer = TextParsing.cleanOptional(newWheelSetRimManufacturer)
        ws.rimModel = TextParsing.cleanOptional(newWheelSetRimModel)
        ws.rimCenterBoreMM = TextParsing.parseDouble(newWheelSetRimCenterBoreText)
        ws.rimBoltPattern = TextParsing.cleanOptional(newWheelSetRimBoltPattern)

        modelContext.insert(ws)
        vehicle.wheelSets.append(ws)

        newWheelSetName = ""
        newWheelSetTireManufacturer = ""
        newWheelSetTireModel = ""
        newWheelSetTireSeasonRaw = ""
        newWheelSetTireStuddedChoice = -1
        newWheelSetTireWidthText = ""
        newWheelSetTireProfileText = ""
        newWheelSetTireDiameter = 0
        newWheelSetTireSpeedIndex = ""
        newWheelSetTireCount = 4
        newWheelSetTireYearTexts = ["", "", "", ""]

        newWheelSetRimManufacturer = ""
        newWheelSetRimModel = ""
        newWheelSetRimTypeRaw = ""
        newWheelSetRimDiameter = 0
        newWheelSetRimWidth = 0
        newWheelSetRimOffsetET = Self.rimOffsetNoneToken
        newWheelSetRimCenterBoreText = ""
        newWheelSetRimBoltPattern = ""

        return ws
    }

    init(entry: LogEntry, existingEntries: [LogEntry]) {
        self.entry = entry
        self.existingEntries = existingEntries

        _kind = State(initialValue: entry.kind)
        _date = State(initialValue: entry.date)
        _odometerText = State(initialValue: entry.odometerKm.map { String($0) } ?? "")
        let initialCostText = entry.totalCost.map { String(format: "%.2f", $0) } ?? ""
        _costText = State(initialValue: initialCostText)
        _notes = State(initialValue: (entry.kind == .service || entry.kind == .tireService || entry.kind == .purchase || entry.kind == .tolls) ? "" : (entry.notes ?? ""))
        _fuelFillKind = State(initialValue: entry.fuelFillKind)

        _litersText = State(initialValue: entry.fuelLiters.map { String($0) } ?? "")
        _pricePerLiterText = State(initialValue: entry.fuelPricePerLiter.map { String($0) } ?? "")

        let existingStation = (entry.fuelStation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if ["Лукойл", "Газпромнефть", "Роснефть", "Татнефть", "Teboil"].contains(existingStation) || existingStation.isEmpty {
            _stationChoice = State(initialValue: existingStation)
            _customStation = State(initialValue: "")
        } else {
            _stationChoice = State(initialValue: Self.stationCustomToken)
            _customStation = State(initialValue: existingStation)
        }

        let mergedServiceDetails = [entry.serviceDetails, entry.notes]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        _serviceDetails = State(initialValue: mergedServiceDetails)
        _maintenanceIntervalIDs = State(initialValue: Set(entry.linkedMaintenanceIntervalIDs))

        let checklist = entry.serviceChecklistItems
        if (entry.kind == .service || entry.kind == .tireService) && checklist.isEmpty {
            _serviceChecklistItems = State(initialValue: [""])
        } else {
            _serviceChecklistItems = State(initialValue: checklist)
        }

        _tireWheelSetChoice = State(initialValue: entry.wheelSetID?.uuidString ?? "")
        _newWheelSetName = State(initialValue: "")
        _newWheelSetTireManufacturer = State(initialValue: "")
        _newWheelSetTireModel = State(initialValue: "")
        _newWheelSetTireSeasonRaw = State(initialValue: "")
        _newWheelSetTireStuddedChoice = State(initialValue: -1)
        _newWheelSetTireWidthText = State(initialValue: "")
        _newWheelSetTireProfileText = State(initialValue: "")
        _newWheelSetTireDiameter = State(initialValue: 0)
        _newWheelSetTireSpeedIndex = State(initialValue: "")
        _newWheelSetTireCount = State(initialValue: 4)
        _newWheelSetTireYearTexts = State(initialValue: ["", "", "", ""])

        _newWheelSetRimManufacturer = State(initialValue: "")
        _newWheelSetRimModel = State(initialValue: "")
        _newWheelSetRimTypeRaw = State(initialValue: "")
        _newWheelSetRimDiameter = State(initialValue: 0)
        _newWheelSetRimWidth = State(initialValue: 0)
        _newWheelSetRimOffsetET = State(initialValue: Self.rimOffsetNoneToken)
        _newWheelSetRimCenterBoreText = State(initialValue: "")
        _newWheelSetRimBoltPattern = State(initialValue: "")

        _vendor = State(initialValue: entry.purchaseVendor ?? "")

        let rawItems = entry.purchaseItems
        let items = (entry.kind == .purchase && rawItems.isEmpty) ? [.init(title: "", price: nil)] : rawItems
        _purchaseItems = State(initialValue: items)
        _purchasePriceTexts = State(initialValue: items.map { item in
            item.price.map { String(format: "%.2f", $0) } ?? ""
        })

        let sum: Double? = {
            let prices = items.compactMap { $0.price }
            guard !prices.isEmpty else { return nil }
            return prices.reduce(0, +)
        }()
        let formattedSum = sum.map { String(format: "%.2f", $0) } ?? ""
        _purchaseLastAutoCostText = State(initialValue: formattedSum)
        _purchaseDidUserEditTotalCost = State(initialValue: !initialCostText.isEmpty && initialCostText != formattedSum)
        
        _tollRoad = State(initialValue: entry.tollRoad ?? entry.tollZone ?? "")
        _tollStart = State(initialValue: entry.tollStart ?? "")
        _tollEnd = State(initialValue: entry.tollEnd ?? "")
        _carwashLocation = State(initialValue: entry.carwashLocation ?? "")
        _parkingLocation = State(initialValue: entry.parkingLocation ?? "")
        _finesViolationType = State(initialValue: entry.finesViolationType ?? "")
    }

    private var computedFuelCost: Double? {
        guard kind == .fuel,
              let liters = TextParsing.parseDouble(litersText),
              let price = TextParsing.parseDouble(pricePerLiterText)
        else { return nil }
        return liters * price
    }

    private func syncFuelCostText() {
        guard kind == .fuel else { return }
        if let c = computedFuelCost {
            costText = String(format: "%.2f", c)
        } else {
            costText = ""
        }
    }

    private var computedPurchaseItemsTotal: Double? {
        let values = purchasePriceTexts.compactMap { TextParsing.parseDouble($0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private func syncPurchaseCostTextIfNeeded() {
        guard kind == .purchase else { return }
        guard !purchaseDidUserEditTotalCost else { return }

        if let sum = computedPurchaseItemsTotal {
            let text = String(format: "%.2f", sum)
            purchaseLastAutoCostText = text
            costText = text
        } else {
            purchaseLastAutoCostText = ""
            costText = ""
        }
    }

    private var computedFuelConsumption: Double? {
        guard kind == .fuel else { return nil }
        return FuelConsumption.compute(
            currentEntryID: entry.id,
            currentDate: date,
            currentOdo: parsedOdometer,
            currentLitersDraft: TextParsing.parseDouble(litersText),
            currentFillKind: fuelFillKind,
            existingEntries: existingEntries
        )
    }

    private var parsedOdometer: Int? {
        let t = odometerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        return Int(t)
    }

    private var maxKnownOdometerExcludingCurrent: Int? {
        existingEntries
            .filter { $0.id != entry.id }
            .compactMap { $0.odometerKm }
            .max()
    }

    private var odometerWarningText: String? {
        guard let odo = parsedOdometer else { return nil }
        guard let maxKnown = maxKnownOdometerExcludingCurrent else { return nil }
        guard odo < maxKnown else { return nil }
        return String(format: String(localized: "warning.odometer.decreased"), String(maxKnown))
    }

    private var odometerIsInvalid: Bool {
        let t = odometerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        guard let v = Int(t) else { return true }
        return v < 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "entry.field.kind"), selection: $kind) {
                        ForEach(LogEntryKind.allCases) { k in
                            Label(k.title, systemImage: k.systemImage).tag(k)
                        }
                    }
                    DatePicker(String(localized: "entry.field.date"), selection: $date, displayedComponents: [.date, .hourAndMinute])

                    TextField(String(localized: "entry.field.odometer.optional"), text: $odometerText).keyboardType(.numberPad)

                    if kind != .fuel || shouldShowComputedFuelCostRow {
                        TextField(String(localized: "entry.field.totalCost"), text: $costText)
                            .keyboardType(.decimalPad)
                            .disabled(kind == .fuel)
                    }

                    if let warn = odometerWarningText {
                        Label(warn, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if kind == .fuel, let cons = computedFuelConsumption {
                        HStack {
                            Label(String(localized: "entry.fuel.consumption"), systemImage: "gauge.with.dots.needle.67percent")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(cons.formatted(.number.precision(.fractionLength(1)))) \(String(localized: "unit.l_per_100km"))")
                        }
                        .font(.subheadline)
                    }
                }

                if kind == .fuel {
                    Section(String(localized: "entry.section.fuel")) {
                        Picker(String(localized: "entry.field.fuelFillKind"), selection: $fuelFillKind) {
                            ForEach([FuelFillKind.partial, FuelFillKind.full]) { k in
                                Text(k.title).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField(String(localized: "entry.field.liters"), text: $litersText).keyboardType(.decimalPad)
                        TextField(String(localized: "entry.field.pricePerLiter"), text: $pricePerLiterText).keyboardType(.decimalPad)

                        Picker(String(localized: "entry.field.station"), selection: $stationChoice) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(fuelStationPresets, id: \.self) { s in
                                Text(s).tag(s)
                            }
                            Text(String(localized: "fuel.station.other")).tag(Self.stationCustomToken)
                        }

                        if stationChoice == Self.stationCustomToken {
                            TextField(
                                String(localized: "fuel.station.custom.placeholder"),
                                text: $customStation
                            )
                        }
                    }
                }

                if kind == .service || kind == .tireService {
                    Section(kind == .tireService ? String(localized: "entry.section.tireService") : String(localized: "entry.section.service")) {
                        if kind == .tireService {
                            Picker(String(localized: "entry.field.wheelSetAfter"), selection: $tireWheelSetChoice) {
                                Text(String(localized: "wheelSet.choice.noChange")).tag("")
                                ForEach(sortedWheelSets) { ws in
                                    Text(ws.name).tag(ws.id.uuidString)
                                }
                                Text(String(localized: "wheelSet.choice.addNew")).tag(Self.wheelSetAddToken)
                            }

                            if tireWheelSetChoice == Self.wheelSetAddToken {
                                TextField(String(localized: "wheelSet.field.name"), text: $newWheelSetName)
                                    .textInputAutocapitalization(.words)

                                SectionHeaderText(String(localized: "wheelSet.section.tires"))

                                TextField(String(localized: "wheelSet.field.tireManufacturer"), text: $newWheelSetTireManufacturer)
                                    .textInputAutocapitalization(.words)
                                TextField(String(localized: "wheelSet.field.tireModel"), text: $newWheelSetTireModel)
                                    .textInputAutocapitalization(.words)

                                Picker(String(localized: "wheelSet.field.tireSeason"), selection: $newWheelSetTireSeasonRaw) {
                                    Text(String(localized: "vehicle.choice.notSet")).tag("")
                                    ForEach(TireSeason.allCases) { s in
                                        Text(s.title).tag(s.rawValue)
                                    }
                                }
                                if TireSeason(rawValue: newWheelSetTireSeasonRaw) == .winter {
                                    Picker(String(localized: "wheelSet.field.tireStuds"), selection: $newWheelSetTireStuddedChoice) {
                                        Text(String(localized: "vehicle.choice.notSet")).tag(-1)
                                        Text(String(localized: "wheelSet.tireStuds.studded")).tag(1)
                                        Text(String(localized: "wheelSet.tireStuds.nonStudded")).tag(0)
                                    }
                                    .pickerStyle(.segmented)
                                }

                                HStack {
                                    TextField(String(localized: "wheelSet.field.tireWidth"), text: $newWheelSetTireWidthText)
                                        .keyboardType(.numberPad)
                                    TextField(String(localized: "wheelSet.field.tireProfile"), text: $newWheelSetTireProfileText)
                                        .keyboardType(.numberPad)
                                }

                                Picker(String(localized: "wheelSet.field.tireDiameter"), selection: $newWheelSetTireDiameter) {
                                    Text(String(localized: "vehicle.choice.notSet")).tag(0)
                                    ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                                        Text("R\(d)").tag(d)
                                    }
                                }

                                TextField(String(localized: "wheelSet.field.tireSpeedIndex"), text: $newWheelSetTireSpeedIndex)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()

                                Picker(String(localized: "wheelSet.field.tireCount"), selection: $newWheelSetTireCount) {
                                    Text("2").tag(2)
                                    Text("4").tag(4)
                                }
                                .pickerStyle(.segmented)

                                Button(String(localized: "wheelSet.tireYears.preset.same")) {
                                    applySameYearPresetForNewWheelSet()
                                }
                                .disabled(newWheelSetTireYearTexts.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false)

                                let visibleYears = (newWheelSetTireCount == 2) ? 2 : 4
                                ForEach(0..<visibleYears, id: \.self) { idx in
                                    TextField(
                                        String.localizedStringWithFormat(String(localized: "wheelSet.field.tireYear"), idx + 1),
                                        text: Binding(
                                            get: { newWheelSetTireYearTexts.indices.contains(idx) ? newWheelSetTireYearTexts[idx] : "" },
                                            set: { newValue in
                                                if newWheelSetTireYearTexts.indices.contains(idx) {
                                                    newWheelSetTireYearTexts[idx] = newValue
                                                }
                                            }
                                        )
                                    )
                                    .keyboardType(.numberPad)
                                }

                                SectionHeaderText(String(localized: "wheelSet.section.rims"))

                                TextField(String(localized: "wheelSet.field.rimManufacturer"), text: $newWheelSetRimManufacturer)
                                    .textInputAutocapitalization(.words)
                                TextField(String(localized: "wheelSet.field.rimModel"), text: $newWheelSetRimModel)
                                    .textInputAutocapitalization(.words)

                                Picker(String(localized: "wheelSet.field.rimType"), selection: $newWheelSetRimTypeRaw) {
                                    Text(String(localized: "vehicle.choice.notSet")).tag("")
                                    ForEach(RimType.allCases) { t in
                                        Text(t.title).tag(t.rawValue)
                                    }
                                }

                                Picker(String(localized: "wheelSet.field.rimDiameter"), selection: $newWheelSetRimDiameter) {
                                    Text(String(localized: "vehicle.choice.notSet")).tag(0)
                                    ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                                        Text("R\(d)").tag(d)
                                    }
                                }

                                Picker(String(localized: "wheelSet.field.rimWidth"), selection: $newWheelSetRimWidth) {
                                    Text(String(localized: "vehicle.choice.notSet")).tag(0.0)
                                    ForEach(WheelSpecsCatalog.rimWidthChoices, id: \.self) { w in
                                        Text("\(WheelSpecsCatalog.formatWidth(w))J").tag(w)
                                    }
                                }

                                Picker(String(localized: "wheelSet.field.rimOffset"), selection: $newWheelSetRimOffsetET) {
                                    Text(String(localized: "vehicle.choice.notSet")).tag(Self.rimOffsetNoneToken)
                                    ForEach(WheelSpecsCatalog.rimOffsetChoices, id: \.self) { et in
                                        Text("ET\(et)").tag(et)
                                    }
                                }

                                TextField(String(localized: "wheelSet.field.rimCenterBore"), text: $newWheelSetRimCenterBoreText)
                                    .keyboardType(.decimalPad)
                                TextField(String(localized: "wheelSet.field.rimBoltPattern"), text: $newWheelSetRimBoltPattern)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                            }
                        }

                        let allIntervals = (entry.vehicle?.maintenanceIntervals ?? []).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                        let linkedIntervals: [MaintenanceInterval] = kind == .service ? allIntervals.filter { maintenanceIntervalIDs.contains($0.id) } : []

                        if kind == .service {
                            DisclosureGroup {
                                ForEach(allIntervals) { interval in
                                    Toggle(isOn: Binding(
                                        get: { maintenanceIntervalIDs.contains(interval.id) },
                                        set: { isOn in
                                            if isOn {
                                                maintenanceIntervalIDs.insert(interval.id)
                                            } else {
                                                maintenanceIntervalIDs.remove(interval.id)
                                            }
                                        }
                                    )) {
                                        Text(interval.title)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(String(localized: "entry.field.maintenanceInterval"))
                                    Spacer()
                                    if maintenanceIntervalIDs.isEmpty {
                                        Text(String(localized: "entry.field.maintenanceInterval.none"))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(String.localizedStringWithFormat(String(localized: "entry.service.link.summary"), maintenanceIntervalIDs.count))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        SectionHeaderText(String(localized: "entry.service.checklist.title"))

                        ForEach(serviceChecklistItems.indices, id: \.self) { idx in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.secondary)

                                TextField(
                                    String(localized: "entry.service.checklist.item.placeholder"),
                                    text: Binding(
                                        get: { serviceChecklistItems[idx] },
                                        set: { serviceChecklistItems[idx] = $0 }
                                    ),
                                    axis: .vertical
                                )
                                .lineLimit(1...3)

                                Button {
                                    serviceChecklistItems.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        Button(String(localized: "entry.service.checklist.addItem")) {
                            serviceChecklistItems.append("")
                        }

                        Button(String(localized: "attachments.action.add")) {
                            isImportingAttachments = true
                        }

                        if let msg = attachmentImportError {
                            Text(msg)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if !entry.attachments.isEmpty {
                            ForEach(entry.attachments.sorted { $0.createdAt > $1.createdAt }) { att in
                                AttachmentRow(
                                    att: att,
                                    linkedIntervals: linkedIntervals,
                                    errorText: $attachmentImportError
                                )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteAttachment(att)
                                        } label: {
                                            Label(String(localized: "action.delete"), systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }

                if kind == .purchase {
                    Section(String(localized: "entry.section.purchase")) {
                        TextField(String(localized: "entry.field.purchaseVendor"), text: $vendor)

                        ForEach(purchaseItems.indices, id: \.self) { idx in
                            HStack(spacing: 10) {
                                Image(systemName: "cart")
                                    .foregroundStyle(.secondary)

                                TextField(
                                    String(localized: "entry.purchase.item.placeholder"),
                                    text: Binding(
                                        get: { purchaseItems[idx].title },
                                        set: { purchaseItems[idx].title = $0 }
                                    ),
                                    axis: .vertical
                                )
                                .lineLimit(1...2)

                                TextField(
                                    String(localized: "entry.purchase.item.price.placeholder"),
                                    text: Binding(
                                        get: { purchasePriceTexts.indices.contains(idx) ? purchasePriceTexts[idx] : "" },
                                        set: { newValue in
                                            while purchasePriceTexts.count <= idx { purchasePriceTexts.append("") }
                                            purchasePriceTexts[idx] = newValue
                                            syncPurchaseCostTextIfNeeded()
                                        }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)

                                Button {
                                    purchaseItems.remove(at: idx)
                                    if purchasePriceTexts.indices.contains(idx) {
                                        purchasePriceTexts.remove(at: idx)
                                    }
                                    syncPurchaseCostTextIfNeeded()
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        Button(String(localized: "entry.purchase.addItem")) {
                            purchaseItems.append(.init(title: "", price: nil))
                            purchasePriceTexts.append("")
                        }
                    }
                }                
                if kind == .tolls {
                    Section(String(localized: "entry.detail.tolls")) {
                        TextField(
                            String(localized: "entry.field.tollRoad"),
                            text: $tollRoad,
                            prompt: Text(String(localized: "entry.field.tollRoad.prompt"))
                        )
                        TextField(String(localized: "entry.field.tollStart"), text: $tollStart)
                        TextField(String(localized: "entry.field.tollEnd"), text: $tollEnd)
                    }
                }
                
                if kind == .carwash {
                    Section(String(localized: "entry.detail.carwash")) {
                        TextField(String(localized: "entry.field.carwashLocation"), text: $carwashLocation)
                    }
                }
                
                if kind == .parking {
                    Section(String(localized: "entry.detail.parking")) {
                        TextField(String(localized: "entry.field.parkingLocation"), text: $parkingLocation)
                    }
                }
                
                if kind == .fines {
                    Section(String(localized: "entry.detail.fines")) {
                        TextField(String(localized: "entry.field.finesViolationType"), text: $finesViolationType)
                    }
                }
                if kind == .service || kind == .tireService {
                    Section(String(localized: "entry.field.details")) {
                        TextField(String(localized: "entry.field.details"), text: $serviceDetails, axis: .vertical)
                            .lineLimit(1...12)
                    }
                } else if kind != .fuel && kind != .purchase && kind != .tolls {
                    Section(String(localized: "entry.section.note")) {
                        TextField(String(localized: "entry.field.notes"), text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }
            }
            .navigationTitle(navigationTitleText)
            .fileImporter(
                isPresented: $isImportingAttachments,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    importAttachments(urls: urls)
                case .failure(let error):
                    attachmentImportError = error.localizedDescription
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        let computedCost: Double?
                        if kind == .fuel {
                            computedCost = computedFuelCost
                        } else {
                            computedCost = TextParsing.parseDouble(costText)
                        }
                        entry.kind = kind
                        entry.date = date
                        entry.odometerKm = parsedOdometer
                        entry.totalCost = computedCost
                        entry.notes = (kind == .fuel || kind == .service || kind == .tireService || kind == .purchase || kind == .tolls) ? nil : TextParsing.cleanOptional(notes)

                        if kind == .fuel {
                            entry.fuelFillKind = fuelFillKind
                            entry.fuelLiters = TextParsing.parseDouble(litersText)
                            entry.fuelPricePerLiter = TextParsing.parseDouble(pricePerLiterText)
                            entry.fuelStation = TextParsing.cleanOptional(resolvedStation)
                            entry.fuelConsumptionLPer100km = computedFuelConsumption
                        } else {
                            entry.fuelLiters = nil
                            entry.fuelPricePerLiter = nil
                            entry.fuelStation = nil
                            entry.fuelConsumptionLPer100km = nil
                            entry.fuelFillKindRaw = nil
                        }

                        if kind == .service || kind == .tireService {
                            entry.serviceTitle = computedServiceTitleFromChecklist
                            entry.serviceDetails = TextParsing.cleanOptional(serviceDetails)
                            entry.setLinkedMaintenanceIntervals(kind == .service ? Array(maintenanceIntervalIDs) : [])
                            entry.setServiceChecklistItems(serviceChecklistItems)

                            if kind == .service {
                                // Keep attachment-to-interval mappings consistent with current links.
                                let linked = Set(maintenanceIntervalIDs)
                                for att in entry.attachments {
                                    if att.appliesToAllMaintenanceIntervals { continue }

                                    let scoped = Set(att.scopedMaintenanceIntervalIDs)
                                    if scoped.isEmpty { continue } // explicit "none"

                                    let intersect = scoped.intersection(linked)
                                    if linked.isEmpty { continue }

                                    if intersect.isEmpty {
                                        // If previously scoped intervals were removed, fall back to "all" for remaining.
                                        att.setAppliesToAllMaintenanceIntervals()
                                    } else if intersect.count == linked.count {
                                        // Store "all" explicitly via the flag.
                                        att.setAppliesToAllMaintenanceIntervals()
                                    } else {
                                        att.setScopedMaintenanceIntervals(Array(intersect))
                                    }
                                }
                            } else {
                                // Tire service: interval linking is not used.
                                for att in entry.attachments {
                                    att.setAppliesToAllMaintenanceIntervals()
                                }
                            }
                        } else {
                            entry.serviceTitle = nil
                            entry.serviceDetails = nil
                            entry.setLinkedMaintenanceIntervals([])
                            entry.setServiceChecklistItems([])
                        }

                        if kind == .tireService {
                            let shouldUpdateVehicle = isLatestTireServiceEntry(using: date)
                            if tireWheelSetChoice.isEmpty {
                                entry.wheelSetID = nil
                            } else if tireWheelSetChoice == Self.wheelSetAddToken {
                                if let ws = createWheelSetFromDraftIfNeeded() {
                                    entry.wheelSetID = ws.id
                                    tireWheelSetChoice = ws.id.uuidString
                                    if shouldUpdateVehicle {
                                        entry.vehicle?.currentWheelSetID = ws.id
                                    }
                                } else {
                                    entry.wheelSetID = nil
                                }
                            } else if let id = UUID(uuidString: tireWheelSetChoice) {
                                entry.wheelSetID = id
                                if shouldUpdateVehicle {
                                    entry.vehicle?.currentWheelSetID = id
                                }
                            } else {
                                entry.wheelSetID = nil
                            }
                        } else {
                            entry.wheelSetID = nil
                        }

                        if kind == .purchase {
                            entry.purchaseCategory = nil
                            entry.purchaseVendor = TextParsing.cleanOptional(vendor)

                            let mapped: [LogEntry.PurchaseItem] = purchaseItems.indices.map { idx in
                                let title = purchaseItems[idx].title
                                let price = purchasePriceTexts.indices.contains(idx) ? TextParsing.parseDouble(purchasePriceTexts[idx]) : nil
                                return .init(title: title, price: price)
                            }
                            entry.setPurchaseItems(mapped)
                        } else {
                            entry.purchaseCategory = nil
                            entry.purchaseVendor = nil
                            entry.setPurchaseItems([])
                        }
                        
                        if kind == .tolls {
                            entry.tollRoad = TextParsing.cleanOptional(tollRoad)
                            entry.tollStart = TextParsing.cleanOptional(tollStart)
                            entry.tollEnd = TextParsing.cleanOptional(tollEnd)
                            entry.tollZone = nil
                        } else {
                            entry.tollRoad = nil
                            entry.tollStart = nil
                            entry.tollEnd = nil
                            entry.tollZone = nil
                        }
                        
                        if kind == .carwash {
                            entry.carwashLocation = TextParsing.cleanOptional(carwashLocation)
                        } else {
                            entry.carwashLocation = nil
                        }
                        
                        if kind == .parking {
                            entry.parkingLocation = TextParsing.cleanOptional(parkingLocation)
                        } else {
                            entry.parkingLocation = nil
                        }
                        
                        if kind == .fines {
                            entry.finesViolationType = TextParsing.cleanOptional(finesViolationType)
                        } else {
                            entry.finesViolationType = nil
                        }

                        // Пересчитать расход по всем топливным записям после любых правок
                        // (в т.ч. когда пробег добавили задним числом или поменяли тип/дату/литры)
                        // Соберём актуальный список: добавим отредактированную запись, дедуплицируем и отсортируем.
                        var merged = existingEntries
                        merged.append(entry)

                        var seen = Set<UUID>()
                        merged = merged.filter { seen.insert($0.id).inserted }

                        // детерминированный порядок для пересчёта: дата (возр.), затем пробег (возр.)
                        merged.sort {
                            if $0.date != $1.date { return $0.date < $1.date }
                            let a = $0.odometerKm ?? Int.min
                            let b = $1.odometerKm ?? Int.min
                            return a < b
                        }

                        FuelConsumption.recalculateAll(existingEntries: merged)

                        do {
                            try modelContext.save()
                            if let vehicle = entry.vehicle {
                                let currentKm = merged.compactMap { $0.odometerKm }.max() ?? vehicle.initialOdometerKm
                                Task {
                                    await MaintenanceNotifications.syncAll(for: vehicle, currentKm: currentKm)
                                }
                            }
                            dismiss()
                        } catch {
                            #if DEBUG
                            assertionFailure("Failed to save edited entry: \(error)")
                            #endif
                            print("Failed to save edited entry: \(error)")
                        }
                    }
                    .disabled(odometerIsInvalid || (kind == .tireService && tireWheelSetChoice == Self.wheelSetAddToken && !isNewWheelSetDraftValid))
                }
            }
        }
        .onAppear {
            syncFuelCostText()
        }
        .onChange(of: stationChoice) { _, newValue in
            if newValue != Self.stationCustomToken {
                customStation = ""
            }
        }
        .onChange(of: kind) { _, _ in
            syncFuelCostText()
            if kind == .purchase {
                if purchaseItems.isEmpty {
                    purchaseItems = [.init(title: "", price: nil)]
                    purchasePriceTexts = [""]
                }
                purchaseDidUserEditTotalCost = !costText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                purchaseLastAutoCostText = ""
                syncPurchaseCostTextIfNeeded()
            } else {
                purchaseDidUserEditTotalCost = false
                purchaseLastAutoCostText = ""
            }

            if kind == .service || kind == .tireService {
                if serviceChecklistItems.isEmpty {
                    serviceChecklistItems = [""]
                }
            }
        }
        .onChange(of: costText) { _, newValue in
            guard kind == .purchase else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                purchaseDidUserEditTotalCost = false
                purchaseLastAutoCostText = ""
                syncPurchaseCostTextIfNeeded()
                return
            }
            if newValue != purchaseLastAutoCostText {
                purchaseDidUserEditTotalCost = true
            }
        }
        .onChange(of: litersText) { _, _ in
            syncFuelCostText()
        }
        .onChange(of: pricePerLiterText) { _, _ in
            syncFuelCostText()
        }
    }

    private func importAttachments(urls: [URL]) {
        attachmentImportError = nil
        for url in urls {
            do {
                let imported = try AttachmentsStore.importFile(from: url)
                let att = Attachment(
                    originalFileName: imported.originalFileName,
                    uti: imported.uti,
                    relativePath: imported.relativePath,
                    fileSizeBytes: imported.fileSizeBytes,
                    logEntry: entry
                )
                modelContext.insert(att)
                entry.attachments.append(att)
            } catch {
                attachmentImportError = error.localizedDescription
            }
        }

        do {
            try modelContext.save()
        } catch {
            attachmentImportError = error.localizedDescription
        }
    }

    private func deleteAttachment(_ att: Attachment) {
        AttachmentsStore.deleteFile(relativePath: att.relativePath)
        modelContext.delete(att)
        do { try modelContext.save() } catch { attachmentImportError = error.localizedDescription }
    }
}

private struct AttachmentRow: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var att: Attachment
    let linkedIntervals: [MaintenanceInterval]
    @Binding var errorText: String?

    private var displayName: String {
        let trimmed = att.originalFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? att.relativePath : trimmed
    }

    private var selectionSummaryText: String {
        guard !linkedIntervals.isEmpty else { return String(localized: "attachments.scope.none") }
        if att.appliesToAllMaintenanceIntervals { return String(localized: "attachments.scope.all") }

        let selected = Set(att.scopedMaintenanceIntervalIDs)
        if selected.isEmpty { return String(localized: "attachments.scope.none") }
        return String.localizedStringWithFormat(String(localized: "attachments.scope.count"), selected.count, linkedIntervals.count)
    }

    private func applyToAllIntervals() {
        errorText = nil
        att.setAppliesToAllMaintenanceIntervals()
        do {
            try modelContext.save()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func applyToNoIntervals() {
        errorText = nil
        att.setScopedMaintenanceIntervals([])
        do {
            try modelContext.save()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func toggleInterval(_ id: UUID) {
        errorText = nil

        let all = Set(linkedIntervals.map { $0.id })
        let selected = Set(att.scopedMaintenanceIntervalIDs)

        if att.appliesToAllMaintenanceIntervals {
            // Currently "all". Toggling means excluding this one.
            var explicit = all
            explicit.remove(id)
            att.setScopedMaintenanceIntervals(Array(explicit))
        } else {
            var next = selected
            if next.contains(id) {
                next.remove(id)
            } else {
                next.insert(id)
            }

            if next == all {
                att.setAppliesToAllMaintenanceIntervals()
            } else {
                // May be empty: explicit "none".
                att.setScopedMaintenanceIntervals(Array(next))
            }
        }

        do {
            try modelContext.save()
        } catch {
            errorText = error.localizedDescription
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url = try? AttachmentsStore.fileURL(relativePath: att.relativePath) {
                ShareLink(item: url) {
                    Label(displayName, systemImage: "paperclip")
                }
            } else {
                Label(displayName, systemImage: "paperclip")
            }

            if linkedIntervals.count > 1 {
                HStack(spacing: 8) {
                    Text(String(localized: "attachments.scope.title"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        Button(String(localized: "attachments.scope.applyNone")) {
                            applyToNoIntervals()
                        }

                        Button(String(localized: "attachments.scope.applyAll")) {
                            applyToAllIntervals()
                        }

                        Divider()

                        ForEach(linkedIntervals) { interval in
                            let selected = Set(att.scopedMaintenanceIntervalIDs)
                            let isChecked = att.appliesToAllMaintenanceIntervals ? true : selected.contains(interval.id)
                            Button {
                                toggleInterval(interval.id)
                            } label: {
                                if isChecked {
                                    Label(interval.title, systemImage: "checkmark")
                                } else {
                                    Text(interval.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectionSummaryText)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct SectionHeaderText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
