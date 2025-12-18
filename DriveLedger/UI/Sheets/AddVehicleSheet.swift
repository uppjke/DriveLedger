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
                        let year = TextParsing.parseIntOptional(yearText)
                        let initialOdo = TextParsing.parseIntOptional(initialOdoText)
                        let v = Vehicle(
                            name: TextParsing.cleanRequired(name, fallback: "Автомобиль"),
                            make: TextParsing.cleanOptional(make),
                            model: TextParsing.cleanOptional(model),
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

