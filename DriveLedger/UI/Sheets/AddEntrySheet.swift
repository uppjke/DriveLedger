//
//  AddEntrySheet.swift
//  DriveLedger
//

import SwiftUI
import Foundation
import SwiftData

struct AddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle
    let existingEntries: [LogEntry]
    let onCreate: (LogEntry) -> Void

    private let allowedKinds: [LogEntryKind]

    @State private var kind: LogEntryKind
    @State private var date: Date = Date()
    @State private var odometerText: String
    @State private var costText = ""
    @State private var notes = ""
    @State private var fuelFillKind: FuelFillKind = .partial

    @State private var litersText = ""
    @State private var pricePerLiterText = ""
    @State private var stationChoice = ""
    @State private var customStation = ""

    @State private var serviceDetails = ""

    @State private var maintenanceIntervalIDs: Set<UUID> = []

    @State private var serviceChecklistItems: [String] = []

    @State private var tireWheelSetChoice = ""
    @State private var newWheelSetName = ""
    @State private var newWheelSetTireSizeChoice = ""
    @State private var newWheelSetTireSizeCustom = ""
    @State private var newWheelSetTireSeasonRaw = ""
    @State private var newWheelSetWinterKindRaw = ""
    @State private var newWheelSetRimTypeRaw = ""
    @State private var newWheelSetRimDiameter = 0
    @State private var newWheelSetRimWidth: Double = 0
    @State private var newWheelSetRimOffsetET = Self.rimOffsetNoneToken

    @State private var vendor = ""
    @State private var purchaseItems: [LogEntry.PurchaseItem] = []
    @State private var purchasePriceTexts: [String] = []

    @State private var purchaseDidUserEditTotalCost = false
    @State private var purchaseLastAutoCostText = ""
    
    // Extended category-specific fields
    @State private var tollZone = ""
    @State private var carwashLocation = ""
    @State private var parkingLocation = ""
    @State private var finesViolationType = ""

    private var computedServiceTitleFromChecklist: String? {
        TextParsing.buildServiceTitleFromChecklist(serviceChecklistItems)
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

    private static let stationCustomToken = "__custom__"
    private static let wheelSetAddToken = "__addWheelSet__"
    private static let wheelSetOtherToken = "__other__"
    private static let rimOffsetNoneToken = -999
    private let fuelStationPresets: [String] = [
        "Лукойл",
        "Газпромнефть",
        "Роснефть",
        "Татнефть",
        "Teboil"
    ]

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

    private var sortedWheelSets: [WheelSet] {
        vehicle.wheelSets.sorted { a, b in
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    private var resolvedNewTireSize: String? {
        if newWheelSetTireSizeChoice.isEmpty {
            return nil
        }
        if newWheelSetTireSizeChoice == Self.wheelSetOtherToken {
            return TextParsing.cleanOptional(newWheelSetTireSizeCustom)
        }
        return newWheelSetTireSizeChoice
    }

    private func createWheelSetFromDraftIfNeeded() -> WheelSet? {
        let hasAny = !newWheelSetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(resolvedNewTireSize ?? "").isEmpty
            || !newWheelSetTireSeasonRaw.isEmpty
            || !newWheelSetWinterKindRaw.isEmpty
            || !newWheelSetRimTypeRaw.isEmpty
            || newWheelSetRimDiameter != 0
            || newWheelSetRimWidth != 0
            || newWheelSetRimOffsetET != Self.rimOffsetNoneToken
        guard hasAny else { return nil }

        let name = TextParsing.cleanRequired(newWheelSetName, fallback: String(localized: "wheelSet.defaultName"))
        let tireSeasonRaw = newWheelSetTireSeasonRaw.isEmpty ? nil : newWheelSetTireSeasonRaw
        let winterKindRaw: String? = {
            if TireSeason(rawValue: newWheelSetTireSeasonRaw) == .winter {
                return newWheelSetWinterKindRaw.isEmpty ? nil : newWheelSetWinterKindRaw
            }
            return nil
        }()
        let rimTypeRaw = newWheelSetRimTypeRaw.isEmpty ? nil : newWheelSetRimTypeRaw
        let rimDiameter = newWheelSetRimDiameter == 0 ? nil : newWheelSetRimDiameter
        let rimWidth = newWheelSetRimWidth == 0 ? nil : newWheelSetRimWidth
        let rimOffsetET = newWheelSetRimOffsetET == Self.rimOffsetNoneToken ? nil : newWheelSetRimOffsetET

        let ws = WheelSet(
            name: name,
            tireSize: resolvedNewTireSize,
            tireSeasonRaw: tireSeasonRaw,
            winterTireKindRaw: winterKindRaw,
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
        modelContext.insert(ws)
        vehicle.wheelSets.append(ws)

        newWheelSetName = ""
        newWheelSetTireSizeChoice = ""
        newWheelSetTireSizeCustom = ""
        newWheelSetTireSeasonRaw = ""
        newWheelSetWinterKindRaw = ""
        newWheelSetRimTypeRaw = ""
        newWheelSetRimDiameter = 0
        newWheelSetRimWidth = 0
        newWheelSetRimOffsetET = Self.rimOffsetNoneToken

        return ws
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

    private var computedFuelConsumption: Double? {
        guard kind == .fuel else { return nil }
        return FuelConsumption.compute(
            currentEntryID: nil,
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

    private var maxKnownOdometer: Int? {
        existingEntries
            .compactMap { $0.odometerKm }
            .max()
    }

    private var isOdometerOnlyMode: Bool {
        kind == .odometer && allowedKinds.count == 1
    }

    private var odometerWarningText: String? {
        guard let odo = parsedOdometer else { return nil }
        guard let maxKnown = maxKnownOdometer else { return nil }
        guard odo < maxKnown else { return nil }
        return String(format: String(localized: "warning.odometer.decreased"), String(maxKnown))
    }

    private var odometerIsInvalid: Bool {
        let t = odometerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }        // теперь это необязательное поле
        guard let v = Int(t) else { return true }
        return v < 0
    }

    init(
        vehicle: Vehicle,
        existingEntries: [LogEntry],
        allowedKinds: [LogEntryKind] = [.fuel, .service, .tireService, .purchase, .tolls, .fines, .carwash, .parking],
        initialKind: LogEntryKind? = nil,
        onCreate: @escaping (LogEntry) -> Void
    ) {
        self.vehicle = vehicle
        self.existingEntries = existingEntries
        self.allowedKinds = allowedKinds
        self.onCreate = onCreate

        let preferred = initialKind
        let resolvedKind = (preferred != nil && allowedKinds.contains(preferred!))
            ? preferred!
            : (allowedKinds.first ?? .fuel)
        _kind = State(initialValue: resolvedKind)

        if resolvedKind == .purchase {
            _purchaseItems = State(initialValue: [.init(title: "", price: nil)])
            _purchasePriceTexts = State(initialValue: [""])
        }

        // Odometer refinement should be one quick action: prefill with latest known value.
        if resolvedKind == .odometer, let maxKnown = existingEntries.compactMap({ $0.odometerKm }).max() {
            _odometerText = State(initialValue: String(maxKnown))
        } else {
            _odometerText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if allowedKinds.count > 1 {
                        Picker(String(localized: "entry.field.kind"), selection: $kind) {
                            ForEach(allowedKinds) { k in
                                Label(k.title, systemImage: k.systemImage).tag(k)
                            }
                        }
                    }
                    DatePicker(String(localized: "entry.field.date"), selection: $date, displayedComponents: [.date, .hourAndMinute])

                    TextField(String(localized: "entry.field.odometer.optional"), text: $odometerText).keyboardType(.numberPad)

                    if !isOdometerOnlyMode {
                        if kind != .fuel || shouldShowComputedFuelCostRow {
                            TextField(String(localized: "entry.field.totalCost"), text: $costText)
                                .keyboardType(.decimalPad)
                                .disabled(kind == .fuel)
                        }
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

                                Picker(String(localized: "wheelSet.field.tireSize"), selection: $newWheelSetTireSizeChoice) {
                                    Text(String(localized: "vehicle.choice.notSet")).tag("")
                                    ForEach(WheelSpecsCatalog.commonTireSizes, id: \.self) { s in
                                        Text(s).tag(s)
                                    }
                                    Text(String(localized: "wheelSet.choice.other")).tag(Self.wheelSetOtherToken)
                                }
                                if newWheelSetTireSizeChoice == Self.wheelSetOtherToken {
                                    TextField(String(localized: "wheelSet.field.tireSize"), text: $newWheelSetTireSizeCustom)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                }

                                Picker(String(localized: "wheelSet.field.tireSeason"), selection: $newWheelSetTireSeasonRaw) {
                                    Text(String(localized: "vehicle.choice.notSet")).tag("")
                                    ForEach(TireSeason.allCases) { s in
                                        Text(s.title).tag(s.rawValue)
                                    }
                                }
                                if TireSeason(rawValue: newWheelSetTireSeasonRaw) == .winter {
                                    Picker(String(localized: "wheelSet.field.winterKind"), selection: $newWheelSetWinterKindRaw) {
                                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                                        ForEach(WinterTireKind.allCases) { k in
                                            Text(k.title).tag(k.rawValue)
                                        }
                                    }
                                }

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
                            }
                        }

                        let intervals = vehicle.maintenanceIntervals.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

                        if kind == .service {
                            DisclosureGroup {
                                ForEach(intervals) { interval in
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

                        Text(String(localized: "entry.service.checklist.title"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline) {
                            Text(String(localized: "entry.service.title.preview"))
                            Spacer()
                            Text(computedServiceTitleFromChecklist ?? String(localized: "entry.service.title.empty"))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }

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
                            String(localized: "entry.field.tollZone"),
                            text: $tollZone,
                            prompt: Text(String(localized: "entry.field.tollZone.prompt"))
                        )
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
                if !isOdometerOnlyMode {
                    if kind == .service || kind == .tireService {
                        Section(String(localized: "entry.field.details")) {
                            TextField(String(localized: "entry.field.details"), text: $serviceDetails, axis: .vertical)
                                .lineLimit(1...12)
                        }
                    } else if kind != .fuel && kind != .purchase {
                        Section(String(localized: "entry.section.note")) {
                            TextField(String(localized: "entry.field.notes"), text: $notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "entry.title.new"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        let cost: Double?
                        if kind == .fuel {
                            cost = computedFuelCost
                        } else {
                            cost = TextParsing.parseDouble(costText)
                        }

                        let entry = LogEntry(
                            kind: kind,
                            date: date,
                            odometerKm: parsedOdometer,
                            totalCost: cost,
                            notes: (kind == .fuel || kind == .service || kind == .tireService || kind == .purchase) ? nil : TextParsing.cleanOptional(notes),
                            vehicle: vehicle
                        )

                        if kind == .fuel {
                            entry.fuelFillKind = fuelFillKind
                            entry.fuelLiters = TextParsing.parseDouble(litersText)
                            entry.fuelPricePerLiter = TextParsing.parseDouble(pricePerLiterText)
                            entry.fuelStation = TextParsing.cleanOptional(resolvedStation)
                            entry.fuelConsumptionLPer100km = computedFuelConsumption
                        }
                        if kind == .service || kind == .tireService {
                            entry.serviceTitle = computedServiceTitleFromChecklist
                            entry.serviceDetails = TextParsing.cleanOptional(serviceDetails)
                            entry.setLinkedMaintenanceIntervals(kind == .service ? Array(maintenanceIntervalIDs) : [])
                            entry.setServiceChecklistItems(serviceChecklistItems)

                            if kind == .tireService {
                                if tireWheelSetChoice.isEmpty {
                                    entry.wheelSetID = nil
                                } else if tireWheelSetChoice == Self.wheelSetAddToken {
                                    if let ws = createWheelSetFromDraftIfNeeded() {
                                        entry.wheelSetID = ws.id
                                        WheelSetSelectionLogic.updateVehicleCurrentWheelSetIfLatest(
                                            vehicle: vehicle,
                                            existingEntries: vehicle.entries,
                                            entryID: entry.id,
                                            entryDate: date,
                                            wheelSetID: ws.id
                                        )
                                        tireWheelSetChoice = ws.id.uuidString
                                    } else {
                                        entry.wheelSetID = nil
                                    }
                                } else if let id = UUID(uuidString: tireWheelSetChoice) {
                                    entry.wheelSetID = id
                                    WheelSetSelectionLogic.updateVehicleCurrentWheelSetIfLatest(
                                        vehicle: vehicle,
                                        existingEntries: vehicle.entries,
                                        entryID: entry.id,
                                        entryDate: date,
                                        wheelSetID: id
                                    )
                                } else {
                                    entry.wheelSetID = nil
                                }
                            } else {
                                entry.wheelSetID = nil
                            }
                        } else {
                            entry.setLinkedMaintenanceIntervals([])
                            entry.setServiceChecklistItems([])
                            entry.wheelSetID = nil
                        }
                        if kind == .purchase {
                            entry.purchaseVendor = TextParsing.cleanOptional(vendor)

                            let mapped: [LogEntry.PurchaseItem] = purchaseItems.indices.map { idx in
                                let title = purchaseItems[idx].title
                                let price = purchasePriceTexts.indices.contains(idx) ? TextParsing.parseDouble(purchasePriceTexts[idx]) : nil
                                return .init(title: title, price: price)
                            }
                            entry.setPurchaseItems(mapped)
                        }
                        if kind == .tolls {
                            entry.tollZone = TextParsing.cleanOptional(tollZone)
                        }
                        if kind == .carwash {
                            entry.carwashLocation = TextParsing.cleanOptional(carwashLocation)
                        }
                        if kind == .parking {
                            entry.parkingLocation = TextParsing.cleanOptional(parkingLocation)
                        }
                        if kind == .fines {
                            entry.finesViolationType = TextParsing.cleanOptional(finesViolationType)
                        }

                        onCreate(entry)
                        dismiss()
                    }
                    .disabled(odometerIsInvalid)
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
}

