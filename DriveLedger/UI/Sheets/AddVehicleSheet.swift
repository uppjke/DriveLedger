//
//  AddVehicleSheet.swift
//  DriveLedger
//

import SwiftUI
import Foundation

struct AddVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var makeCustom = ""
    @State private var modelCustom = ""
    @State private var selectedMake = ""
    @State private var selectedModel = ""
    @State private var makeIsCustom = false
    @State private var modelIsCustom = false
    @State private var yearText = ""
    @State private var initialOdoText = ""
    @State private var licensePlate = ""
    @State private var vin = ""
    @State private var isLicensePlateInvalid = false
    @State private var selectedGeneration = ""
    @State private var generationCustom = ""
    @State private var generationIsCustom = false
    @State private var selectedColor = ""
    @State private var colorCustom = ""
    @State private var colorIsCustom = false

    @State private var selectedBodyStyle = ""

    @State private var selectedEngine = ""
    @State private var engineCustom = ""
    @State private var engineIsCustom = false

    let onCreate: (Vehicle) -> Void

    private var generationSuggestions: [String] {
        guard !makeIsCustom, !modelIsCustom else { return [] }
        guard !selectedMake.isEmpty, !selectedModel.isEmpty else { return [] }
        return VehicleCatalog.generations(make: selectedMake, model: selectedModel)
    }

    private var resolvedGenerationValue: String? {
        let gens = generationSuggestions
        if gens.isEmpty {
            return TextParsing.cleanOptional(generationCustom)
        }
        if generationIsCustom {
            return TextParsing.cleanOptional(generationCustom)
        }
        return selectedGeneration.isEmpty ? nil : selectedGeneration
    }

    private var engineSuggestions: [String] {
        guard !makeIsCustom, !modelIsCustom else { return [] }
        guard !selectedMake.isEmpty, !selectedModel.isEmpty else { return [] }
        return VehicleCatalog.engines(make: selectedMake, model: selectedModel, generation: resolvedGenerationValue)
    }

    private var isDomesticKnownSelection: Bool {
        guard !makeIsCustom, !modelIsCustom else { return false }
        guard !selectedMake.isEmpty, !selectedModel.isEmpty else { return false }
        return VehicleCatalog.isDomestic(make: selectedMake)
    }

    private var inferredBodyStyle: String? {
        guard !makeIsCustom, !modelIsCustom else { return nil }
        guard !selectedMake.isEmpty, !selectedModel.isEmpty else { return nil }
        return VehicleCatalog.inferredBodyStyle(make: selectedMake, model: selectedModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "vehicle.section.main")) {
                    TextField(String(localized: "vehicle.field.name"), text: $name)
                        .textInputAutocapitalization(.words)

                    TextField(String(localized: "vehicle.field.plate"), text: $licensePlate)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: licensePlate) { _, newValue in
                            if let normalized = TextParsing.normalizeRussianLicensePlate(newValue) {
                                isLicensePlateInvalid = !TextParsing.isValidRussianPrivateCarPlate(normalized)
                            } else {
                                isLicensePlateInvalid = false
                            }
                        }

                    TextField(String(localized: "vehicle.field.vin"), text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)

                    if isLicensePlateInvalid {
                        Text(String(localized: "vehicle.plate.invalid"))
                            .foregroundStyle(.red)
                    }
                }

                Section(String(localized: "vehicle.section.details")) {
                    Picker(String(localized: "vehicle.field.make"), selection: $selectedMake) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(VehicleCatalog.pickerMakes, id: \.self) { m in
                            Text(m).tag(m)
                        }
                        Text(String(localized: "vehicle.choice.other")).tag("__other__")
                    }
                    .onChange(of: selectedMake) { _, newValue in
                        makeIsCustom = (newValue == "__other__")
                        if !makeIsCustom {
                            makeCustom = ""
                            // reset model picker when make changes
                            selectedModel = ""
                            modelCustom = ""
                            modelIsCustom = false
                        }
                        selectedGeneration = ""
                        generationCustom = ""
                        generationIsCustom = false

                        selectedEngine = ""
                        engineCustom = ""
                        engineIsCustom = false

                        selectedBodyStyle = inferredBodyStyle ?? ""
                    }

                    if makeIsCustom {
                        TextField(String(localized: "vehicle.field.make.custom"), text: $makeCustom)
                            .textInputAutocapitalization(.words)
                    }

                    let models = VehicleCatalog.models(forMake: selectedMake)
                    Picker(String(localized: "vehicle.field.model"), selection: $selectedModel) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(models, id: \.self) { m in
                            Text(m).tag(m)
                        }
                        Text(String(localized: "vehicle.choice.other")).tag("__other__")
                    }
                    .disabled(selectedMake.isEmpty || makeIsCustom)
                    .onChange(of: selectedModel) { _, newValue in
                        modelIsCustom = (newValue == "__other__")
                        if !modelIsCustom {
                            modelCustom = ""
                        }
                        selectedGeneration = ""
                        generationCustom = ""
                        generationIsCustom = false

                        selectedEngine = ""
                        engineCustom = ""
                        engineIsCustom = false

                        selectedBodyStyle = inferredBodyStyle ?? ""
                    }

                    if modelIsCustom {
                        TextField(String(localized: "vehicle.field.model.custom"), text: $modelCustom)
                            .textInputAutocapitalization(.words)
                    }

                    Picker(String(localized: "vehicle.field.bodyStyle"), selection: $selectedBodyStyle) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(VehicleBodyStyleOption.allCases) { opt in
                            Text(opt.title).tag(opt.rawValue)
                        }
                    }
                    .onAppear {
                        if selectedBodyStyle.isEmpty {
                            selectedBodyStyle = inferredBodyStyle ?? ""
                        }
                    }

                    // Generation: suggestions only when make+model are known.
                    let gens = generationSuggestions

                    if gens.isEmpty {
                        if isDomesticKnownSelection {
                            Picker(String(localized: "vehicle.field.generation"), selection: $selectedGeneration) {
                                Text(String(localized: "vehicle.choice.notSet")).tag("")
                            }
                            .disabled(true)
                        } else {
                            TextField(String(localized: "vehicle.field.generation"), text: $generationCustom)
                                .textInputAutocapitalization(.words)
                        }
                    } else {
                        Picker(String(localized: "vehicle.field.generation"), selection: $selectedGeneration) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(gens, id: \.self) { g in
                                Text(g).tag(g)
                            }
                            if !isDomesticKnownSelection {
                                Text(String(localized: "vehicle.choice.other")).tag("__other__")
                            }
                        }
                        .onChange(of: selectedGeneration) { _, newValue in
                            generationIsCustom = (newValue == "__other__")
                            if !generationIsCustom {
                                generationCustom = ""
                            }
                        }

                        if generationIsCustom && !isDomesticKnownSelection {
                            TextField(String(localized: "vehicle.field.generation.custom"), text: $generationCustom)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    let engines = engineSuggestions
                    if engines.isEmpty {
                        if isDomesticKnownSelection {
                            Picker(String(localized: "vehicle.field.engine"), selection: $selectedEngine) {
                                Text(String(localized: "vehicle.choice.notSet")).tag("")
                            }
                            .disabled(true)
                        } else {
                            TextField(String(localized: "vehicle.field.engine"), text: $engineCustom)
                                .textInputAutocapitalization(.words)
                        }
                    } else {
                        Picker(String(localized: "vehicle.field.engine"), selection: $selectedEngine) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(engines, id: \.self) { e in
                                Text(e).tag(e)
                            }
                            if !isDomesticKnownSelection {
                                Text(String(localized: "vehicle.choice.other")).tag("__other__")
                            }
                        }
                        .onChange(of: selectedEngine) { _, newValue in
                            engineIsCustom = (newValue == "__other__")
                            if !engineIsCustom {
                                engineCustom = ""
                            }
                        }

                        if engineIsCustom && !isDomesticKnownSelection {
                            TextField(String(localized: "vehicle.field.engine.custom"), text: $engineCustom)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    Picker(String(localized: "vehicle.field.color"), selection: $selectedColor) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(VehicleColorOption.allCases) { opt in
                            HStack {
                                Circle()
                                    .fill(opt.swatch)
                                    .frame(width: 12, height: 12)
                                Text(opt.title)
                            }
                            .tag(opt.rawValue)
                        }
                        Text(String(localized: "vehicle.choice.other")).tag("__other__")
                    }
                    .onChange(of: selectedColor) { _, newValue in
                        colorIsCustom = (newValue == "__other__")
                        if !colorIsCustom {
                            colorCustom = ""
                        }
                    }

                    if colorIsCustom {
                        TextField(String(localized: "vehicle.field.color.custom"), text: $colorCustom)
                            .textInputAutocapitalization(.words)
                    }

                    TextField(String(localized: "vehicle.field.year"), text: $yearText)
                        .keyboardType(.numberPad)
                }

                Section(String(localized: "vehicle.section.odometer")) {
                    TextField(String(localized: "vehicle.field.initialOdo"), text: $initialOdoText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(String(localized: "vehicle.title.new"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.create")) {
                        let cleanPlate = TextParsing.normalizeRussianLicensePlate(licensePlate)
                        let cleanVIN = TextParsing.normalizeVIN(vin)

                        if let p = cleanPlate, !TextParsing.isValidRussianPrivateCarPlate(p) {
                            isLicensePlateInvalid = true
                            return
                        }

                        let makeValue = makeIsCustom ? TextParsing.cleanOptional(makeCustom) : (selectedMake.isEmpty ? nil : selectedMake)
                        let modelValue = modelIsCustom ? TextParsing.cleanOptional(modelCustom) : (selectedModel.isEmpty ? nil : selectedModel)
                        let generationValue: String? = {
                            if isDomesticKnownSelection {
                                return selectedGeneration.isEmpty ? nil : selectedGeneration
                            }
                            return resolvedGenerationValue
                        }()
                        let engineValue: String? = {
                            let engines = engineSuggestions
                            if engines.isEmpty {
                                if isDomesticKnownSelection {
                                    return nil
                                }
                                return TextParsing.cleanOptional(engineCustom)
                            }
                            if engineIsCustom {
                                if isDomesticKnownSelection {
                                    return nil
                                }
                                return TextParsing.cleanOptional(engineCustom)
                            }
                            return selectedEngine.isEmpty ? nil : selectedEngine
                        }()
                        let colorValue = colorIsCustom ? TextParsing.cleanOptional(colorCustom) : (selectedColor.isEmpty ? nil : selectedColor)
                        let bodyStyleValue = selectedBodyStyle.isEmpty ? (inferredBodyStyle ?? nil) : selectedBodyStyle

                        // Generate a human-friendly default name if the user leaves it empty.
                        let fallbackName: String = {
                            if let plate = cleanPlate, !plate.isEmpty { return plate }
                            let mm = [makeValue, modelValue].compactMap { $0 }.joined(separator: " ")
                            return mm.isEmpty ? String(localized: "vehicle.defaultName") : mm
                        }()

                        let year = TextParsing.parseIntOptional(yearText)
                        let initialOdo = TextParsing.parseIntOptional(initialOdoText)
                        let v = Vehicle(
                            name: TextParsing.cleanRequired(name, fallback: fallbackName),
                            make: makeValue,
                            model: modelValue,
                            generation: generationValue,
                            year: year,
                            engine: engineValue,
                            bodyStyle: bodyStyleValue,
                            colorName: colorValue,
                            licensePlate: cleanPlate,
                            vin: cleanVIN,
                            iconSymbol: nil,
                            initialOdometerKm: initialOdo
                        )
                        onCreate(v)
                        dismiss()
                    }
                    .disabled((TextParsing.cleanOptional(name) == nil && TextParsing.cleanOptional(licensePlate) == nil && selectedMake.isEmpty && makeCustom.isEmpty) || isLicensePlateInvalid)
                }
            }
        }
    }
}

