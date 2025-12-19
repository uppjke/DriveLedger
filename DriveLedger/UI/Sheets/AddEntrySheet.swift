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

    @State private var kind: LogEntryKind = .fuel
    @State private var date: Date = Date()
    @State private var odometerText = ""
    @State private var costText = ""
    @State private var notes = ""
    @State private var fuelFillKind: FuelFillKind = .full

    @State private var litersText = ""
    @State private var pricePerLiterText = ""
    @State private var station = ""

    @State private var serviceTitle = ""
    @State private var serviceDetails = ""

    @State private var maintenanceIntervalID: UUID?

    @State private var category = ""
    @State private var vendor = ""
    
    // Extended category-specific fields
    @State private var tollZone = ""
    @State private var carwashLocation = ""
    @State private var parkingLocation = ""
    @State private var finesViolationType = ""


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

                if kind == .service {
                    Section(String(localized: "entry.section.service")) {
                        Picker(String(localized: "entry.field.maintenanceInterval"), selection: $maintenanceIntervalID) {
                            Text(String(localized: "entry.field.maintenanceInterval.none")).tag(UUID?.none)
                            ForEach(vehicle.maintenanceIntervals.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) { interval in
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
            .navigationTitle(String(localized: "entry.title.new"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        let cost = TextParsing.parseDouble(costText) ?? computedFuelCost

                        let entry = LogEntry(
                            kind: kind,
                            date: date,
                            odometerKm: parsedOdometer,
                            totalCost: cost,
                            notes: TextParsing.cleanOptional(notes),
                            vehicle: vehicle
                        )

                        if kind == .fuel {
                            entry.fuelFillKind = fuelFillKind
                            entry.fuelLiters = TextParsing.parseDouble(litersText)
                            entry.fuelPricePerLiter = TextParsing.parseDouble(pricePerLiterText)
                            entry.fuelStation = TextParsing.cleanOptional(station)
                            entry.fuelConsumptionLPer100km = computedFuelConsumption
                        }
                        if kind == .service {
                            entry.serviceTitle = TextParsing.cleanOptional(serviceTitle)
                            entry.serviceDetails = TextParsing.cleanOptional(serviceDetails)
                            entry.maintenanceIntervalID = maintenanceIntervalID
                        } else {
                            entry.maintenanceIntervalID = nil
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
    }
}

