//
//  EditVehicleSheet.swift
//  DriveLedger
//

import SwiftUI
import Foundation
import SwiftData

struct EditVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle

    @State private var name: String
    @State private var make: String
    @State private var model: String
    @State private var yearText: String
    @State private var initialOdoText: String

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _name = State(initialValue: vehicle.name)
        _make = State(initialValue: vehicle.make ?? "")
        _model = State(initialValue: vehicle.model ?? "")
        _yearText = State(initialValue: vehicle.year.map(String.init) ?? "")
        _initialOdoText = State(initialValue: vehicle.initialOdometerKm.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Автомобиль") {
                    TextField("Название", text: $name)
                    TextField("Марка", text: $make)
                    TextField("Модель", text: $model)
                    TextField("Год", text: $yearText)
                        .keyboardType(.numberPad)
                    TextField("Пробег при добавлении, км (необязательно)", text: $initialOdoText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Редактировать авто")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        vehicle.name = cleanRequired(name, fallback: "Автомобиль")
                        vehicle.make = cleanOptional(make)
                        vehicle.model = cleanOptional(model)
                        vehicle.year = parseIntOptional(yearText)
                        vehicle.initialOdometerKm = parseIntOptional(initialOdoText)
                        do { try modelContext.save() } catch { }
                        dismiss()
                    }
                }
            }
        }
    }

    private func cleanOptional(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func cleanRequired(_ s: String, fallback: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }

    private func parseIntOptional(_ s: String) -> Int? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Int(t)
    }
}
