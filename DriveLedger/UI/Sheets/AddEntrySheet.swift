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

    @State private var category = ""
    @State private var vendor = ""


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
                    Picker("Тип", selection: $kind) {
                        ForEach(LogEntryKind.allCases) { k in
                            Label(k.title, systemImage: k.systemImage).tag(k)
                        }
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    TextField("Пробег, км (необязательно)", text: $odometerText).keyboardType(.numberPad)
                    TextField("Сумма", text: $costText).keyboardType(.decimalPad)

                    if kind == .fuel, let c = computedFuelCost {
                        HStack {
                            Label("Рассчитано", systemImage: "wand.and.stars")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(c, format: .currency(code: DLFormatters.currencyCode))
                            Button("Подставить") {
                                costText = String(format: "%.2f", c)
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.subheadline)
                    }

                    if kind == .fuel, let cons = computedFuelConsumption {
                        HStack {
                            Label("Расход", systemImage: "gauge.with.dots.needle.67percent")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(cons.formatted(.number.precision(.fractionLength(1)))) л/100км")
                        }
                        .font(.subheadline)
                    }
                }

                if kind == .fuel {
                    Section("Заправка") {
                        Picker("Тип заправки", selection: $fuelFillKind) {
                            ForEach(FuelFillKind.allCases) { k in
                                Text(k.title).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                        TextField("Литры", text: $litersText).keyboardType(.decimalPad)
                        TextField("Цена/л", text: $pricePerLiterText).keyboardType(.decimalPad)
                        TextField("АЗС", text: $station)
                    }
                }

                if kind == .service {
                    Section("Обслуживание") {
                        TextField("Название (например: “Замена масла”)", text: $serviceTitle)
                        TextField("Детали", text: $serviceDetails, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }

                if kind == .purchase {
                    Section("Покупка") {
                        TextField("Категория (например: “Шины”)", text: $category)
                        TextField("Магазин/продавец", text: $vendor)
                    }
                }

                Section("Заметка") {
                    TextField("Комментарий", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Новая запись")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
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
                        }
                        if kind == .purchase {
                            entry.purchaseCategory = TextParsing.cleanOptional(category)
                            entry.purchaseVendor = TextParsing.cleanOptional(vendor)
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

