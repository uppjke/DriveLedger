//
//  EditEntrySheet.swift
//  DriveLedger
//

import SwiftUI
import Foundation
import SwiftData

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
    @State private var station: String

    @State private var serviceTitle: String
    @State private var serviceDetails: String

    @State private var maintenanceIntervalID: UUID?

    @State private var category: String
    @State private var vendor: String
    
    // Extended category-specific fields
    @State private var tollZone: String
    @State private var carwashLocation: String
    @State private var parkingLocation: String
    @State private var finesViolationType: String

    init(entry: LogEntry, existingEntries: [LogEntry]) {
        self.entry = entry
        self.existingEntries = existingEntries

        _kind = State(initialValue: entry.kind)
        _date = State(initialValue: entry.date)
        _odometerText = State(initialValue: entry.odometerKm.map { String($0) } ?? "")
        _costText = State(initialValue: entry.totalCost.map { String(format: "%.2f", $0) } ?? "")
        _notes = State(initialValue: entry.notes ?? "")
        _fuelFillKind = State(initialValue: entry.fuelFillKind)

        _litersText = State(initialValue: entry.fuelLiters.map { String($0) } ?? "")
        _pricePerLiterText = State(initialValue: entry.fuelPricePerLiter.map { String($0) } ?? "")
        _station = State(initialValue: entry.fuelStation ?? "")

        _serviceTitle = State(initialValue: entry.serviceTitle ?? "")
        _serviceDetails = State(initialValue: entry.serviceDetails ?? "")
        _maintenanceIntervalID = State(initialValue: entry.maintenanceIntervalID)

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
                    TextField(String(localized: "entry.field.totalCost"), text: $costText).keyboardType(.decimalPad)

                    if let warn = odometerWarningText {
                        Label(warn, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if kind == .fuel, let c = computedFuelCost {
                        HStack {
                            Label(String(localized: "entry.fuel.computed"), systemImage: "wand.and.stars")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(c, format: .currency(code: DLFormatters.currencyCode))
                            Button(String(localized: "action.apply")) {
                                costText = String(format: "%.2f", c)
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.subheadline)
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
                            ForEach(FuelFillKind.allCases) { k in
                                Text(k.title).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField(String(localized: "entry.field.liters"), text: $litersText).keyboardType(.decimalPad)
                        TextField(String(localized: "entry.field.pricePerLiter"), text: $pricePerLiterText).keyboardType(.decimalPad)
                        TextField(String(localized: "entry.field.station"), text: $station)
                    }
                }

                if kind == .service || kind == .tireService {
                    Section(kind == .tireService ? String(localized: "entry.section.tireService") : String(localized: "entry.section.service")) {
                        Picker(String(localized: "entry.field.maintenanceInterval"), selection: $maintenanceIntervalID) {
                            Text(String(localized: "entry.field.maintenanceInterval.none")).tag(UUID?.none)
                            ForEach((entry.vehicle?.maintenanceIntervals ?? []).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) { interval in
                                Text(interval.title).tag(Optional(interval.id))
                            }
                        }
                        TextField(String(localized: "entry.field.serviceTitle.prompt"), text: $serviceTitle)
                        TextField(String(localized: "entry.field.details"), text: $serviceDetails, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
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
                Section(String(localized: "entry.section.note")) {
                    TextField(String(localized: "entry.field.notes"), text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(String(localized: "entry.title.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        let computedCost = TextParsing.parseDouble(costText) ?? computedFuelCost
                        entry.kind = kind
                        entry.date = date
                        entry.odometerKm = parsedOdometer
                        entry.totalCost = computedCost
                        entry.notes = TextParsing.cleanOptional(notes)

                        if kind == .fuel {
                            entry.fuelFillKind = fuelFillKind
                            entry.fuelLiters = TextParsing.parseDouble(litersText)
                            entry.fuelPricePerLiter = TextParsing.parseDouble(pricePerLiterText)
                            entry.fuelStation = TextParsing.cleanOptional(station)
                            entry.fuelConsumptionLPer100km = computedFuelConsumption
                        } else {
                            entry.fuelLiters = nil
                            entry.fuelPricePerLiter = nil
                            entry.fuelStation = nil
                            entry.fuelConsumptionLPer100km = nil
                            entry.fuelFillKindRaw = nil
                        }

                        if kind == .service {
                            entry.serviceTitle = TextParsing.cleanOptional(serviceTitle)
                            entry.serviceDetails = TextParsing.cleanOptional(serviceDetails)
                            entry.maintenanceIntervalID = maintenanceIntervalID
                        } else {
                            entry.serviceTitle = nil
                            entry.serviceDetails = nil
                            entry.maintenanceIntervalID = nil
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
    }
}
