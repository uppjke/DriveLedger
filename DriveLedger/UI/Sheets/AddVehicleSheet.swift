//
//  AddVehicleSheet.swift
//  DriveLedger
//

import SwiftUI
import Foundation

struct AddVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var make = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var initialOdoText = ""

    let onCreate: (Vehicle) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Автомобиль") {
                    TextField("Название (например: “Моя Mazda”)", text: $name)
                    TextField("Марка", text: $make)
                    TextField("Модель", text: $model)
                    TextField("Год", text: $yearText)
                        .keyboardType(.numberPad)
                    TextField("Пробег при добавлении, км (необязательно)", text: $initialOdoText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Новый автомобиль")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        let year = Int(yearText.trimmingCharacters(in: .whitespacesAndNewlines))
                        let odoTrim = initialOdoText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let initialOdo = odoTrim.isEmpty ? nil : Int(odoTrim)
                        let v = Vehicle(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Автомобиль" : name,
                            make: make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : make,
                            model: model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : model,
                            year: year,
                            initialOdometerKm: initialOdo
                        )
                        onCreate(v)
                        dismiss()
                    }
                }
            }
        }
    }
}
