//
//  AddEntrySheet.swift
//  DriveLedger
//

import SwiftUI
import Foundation

struct AddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

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

    @State private var category = ""
    @State private var vendor = ""
    
    // Extended category-specific fields
    @State private var tollZone = ""
    @State private var carwashLocation = ""
    @State private var parkingLocation = ""
    @State private var finesViolationType = ""

    private var computedServiceTitleFromChecklist: String? {
        TextParsing.buildServiceTitleFromChecklist(serviceChecklistItems)
    }

    private static let stationCustomToken = "__custom__"
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
                        let intervals = vehicle.maintenanceIntervals.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

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
                if !isOdometerOnlyMode {
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
                            notes: (kind == .fuel || kind == .service || kind == .tireService) ? nil : TextParsing.cleanOptional(notes),
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
                            entry.setLinkedMaintenanceIntervals(Array(maintenanceIntervalIDs))
                            entry.setServiceChecklistItems(serviceChecklistItems)
                        } else {
                            entry.setLinkedMaintenanceIntervals([])
                            entry.setServiceChecklistItems([])
                        }
                        if kind == .purchase {
                            entry.purchaseCategory = TextParsing.cleanOptional(category)
                            entry.purchaseVendor = TextParsing.cleanOptional(vendor)
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
        }
        .onChange(of: litersText) { _, _ in
            syncFuelCostText()
        }
        .onChange(of: pricePerLiterText) { _, _ in
            syncFuelCostText()
        }
    }
}

