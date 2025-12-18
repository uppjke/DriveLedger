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

    @State private var category: String
    @State private var vendor: String

    private var currencyCode: String { "RUB" }

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

        _category = State(initialValue: entry.purchaseCategory ?? "")
        _vendor = State(initialValue: entry.purchaseVendor ?? "")
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
                            Text(c, format: .currency(code: currencyCode))
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
            .navigationTitle("Редактировать запись")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let computedCost = TextParsing.parseDouble(costText) ?? computedFuelCost
                        entry.kind = kind
                        entry.date = date
                        entry.odometerKm = parsedOdometer
                        entry.totalCost = computedCost
                        entry.notes = clean(notes)

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
                            entry.serviceTitle = clean(serviceTitle)
                            entry.serviceDetails = clean(serviceDetails)
                        } else {
                            entry.serviceTitle = nil
                            entry.serviceDetails = nil
                        }

                        if kind == .purchase {
                            entry.purchaseCategory = clean(category)
                            entry.purchaseVendor = clean(vendor)
                        } else {
                            entry.purchaseCategory = nil
                            entry.purchaseVendor = nil
                        }

                        // Пересчитать расход по всем топливным записям после любых правок
                        // (в т.ч. когда пробег добавили задним числом или поменяли тип/дату/литры)
                        FuelConsumption.recalculateAll(existingEntries: existingEntries)

                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            // Если сохранение не удалось — остаёмся на экране редактирования.
                            // Позже можно добавить Alert с текстом ошибки.
                        }
                    }
                    .disabled(odometerIsInvalid)
                }
            }
        }
    }

    private func clean(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
