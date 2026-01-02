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
    @State private var newWheelSetTireSizeChoice: String
    @State private var newWheelSetTireSizeCustom: String
    @State private var newWheelSetTireSeasonRaw: String
    @State private var newWheelSetWinterKindRaw: String
    @State private var newWheelSetRimTypeRaw: String
    @State private var newWheelSetRimDiameter: Int
    @State private var newWheelSetRimWidth: Double
    @State private var newWheelSetRimOffsetET: Int

    @State private var category: String
    @State private var vendor: String
    
    // Extended category-specific fields
    @State private var tollZone: String
    @State private var carwashLocation: String
    @State private var parkingLocation: String
    @State private var finesViolationType: String

    @State private var isImportingAttachments = false
    @State private var attachmentImportError: String?

    private var computedServiceTitleFromChecklist: String? {
        TextParsing.buildServiceTitleFromChecklist(serviceChecklistItems)
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

    private func createWheelSetFromDraftIfNeeded() -> WheelSet? {
        guard let vehicle = entry.vehicle else { return nil }

        let resolvedTireSize: String? = {
            if newWheelSetTireSizeChoice.isEmpty { return nil }
            if newWheelSetTireSizeChoice == Self.wheelSetOtherToken {
                return TextParsing.cleanOptional(newWheelSetTireSizeCustom)
            }
            return newWheelSetTireSizeChoice
        }()

        let hasAny = !newWheelSetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(resolvedTireSize ?? "").isEmpty
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
            tireSize: resolvedTireSize,
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

    init(entry: LogEntry, existingEntries: [LogEntry]) {
        self.entry = entry
        self.existingEntries = existingEntries

        _kind = State(initialValue: entry.kind)
        _date = State(initialValue: entry.date)
        _odometerText = State(initialValue: entry.odometerKm.map { String($0) } ?? "")
        _costText = State(initialValue: entry.totalCost.map { String(format: "%.2f", $0) } ?? "")
        _notes = State(initialValue: (entry.kind == .service || entry.kind == .tireService) ? "" : (entry.notes ?? ""))
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

        _serviceChecklistItems = State(initialValue: entry.serviceChecklistItems)

        _tireWheelSetChoice = State(initialValue: entry.wheelSetID?.uuidString ?? "")
        _newWheelSetName = State(initialValue: "")
        _newWheelSetTireSizeChoice = State(initialValue: "")
        _newWheelSetTireSizeCustom = State(initialValue: "")
        _newWheelSetTireSeasonRaw = State(initialValue: "")
        _newWheelSetWinterKindRaw = State(initialValue: "")
        _newWheelSetRimTypeRaw = State(initialValue: "")
        _newWheelSetRimDiameter = State(initialValue: 0)
        _newWheelSetRimWidth = State(initialValue: 0)
        _newWheelSetRimOffsetET = State(initialValue: Self.rimOffsetNoneToken)

        _category = State(initialValue: entry.purchaseCategory ?? "")
        _vendor = State(initialValue: entry.purchaseVendor ?? "")
        
        _tollZone = State(initialValue: entry.tollZone ?? "")
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
                        TextField(String(localized: "entry.field.purchaseCategory.prompt"), text: $category)
                        TextField(String(localized: "entry.field.purchaseVendor"), text: $vendor)
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
                if kind == .service || kind == .tireService {
                    Section(String(localized: "entry.field.details")) {
                        TextField(String(localized: "entry.field.details"), text: $serviceDetails, axis: .vertical)
                            .lineLimit(1...12)
                    }
                } else if kind != .fuel {
                    Section(String(localized: "entry.section.note")) {
                        TextField(String(localized: "entry.field.notes"), text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }
            }
            .navigationTitle(String(localized: "entry.title.edit"))
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
                        entry.notes = (kind == .fuel || kind == .service || kind == .tireService) ? nil : TextParsing.cleanOptional(notes)

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
                            entry.purchaseCategory = TextParsing.cleanOptional(category)
                            entry.purchaseVendor = TextParsing.cleanOptional(vendor)
                        } else {
                            entry.purchaseCategory = nil
                            entry.purchaseVendor = nil
                        }
                        
                        if kind == .tolls {
                            entry.tollZone = TextParsing.cleanOptional(tollZone)
                        } else {
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
