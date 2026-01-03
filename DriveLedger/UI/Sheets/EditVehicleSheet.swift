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
    @State private var makeCustom: String
    @State private var modelCustom: String
    @State private var selectedMake: String
    @State private var selectedModel: String
    @State private var makeIsCustom: Bool
    @State private var modelIsCustom: Bool
    @State private var yearText: String
    @State private var initialOdoText: String
    @State private var licensePlate: String
    @State private var vin: String
    @State private var isLicensePlateInvalid: Bool
    @State private var selectedGeneration: String
    @State private var generationCustom: String
    @State private var generationIsCustom: Bool
    @State private var selectedColor: String
    @State private var colorCustom: String
    @State private var colorIsCustom: Bool

    @State private var selectedEngine: String
    @State private var engineCustom: String
    @State private var engineIsCustom: Bool

    @State private var selectedBodyStyle: String

    @State private var currentWheelSetChoice: String
    @State private var isWheelSetPickerPresented: Bool

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _name = State(initialValue: vehicle.name)
        let makeValue = VehicleCatalog.canonicalMake(vehicle.make) ?? ""
        let modelValue = vehicle.model ?? ""

        let makeIsKnown = VehicleCatalog.isKnownMake(makeValue)
        let models = VehicleCatalog.models(forMake: makeValue)
        let modelIsKnown = models.contains(modelValue)

        _makeIsCustom = State(initialValue: !makeValue.isEmpty && !makeIsKnown)
        _modelIsCustom = State(initialValue: !modelValue.isEmpty && !modelIsKnown)
        _selectedMake = State(initialValue: makeValue.isEmpty ? "" : (makeIsKnown ? makeValue : "__other__"))
        _selectedModel = State(initialValue: modelValue.isEmpty ? "" : (modelIsKnown ? modelValue : "__other__"))
        _makeCustom = State(initialValue: (!makeValue.isEmpty && !makeIsKnown) ? makeValue : "")
        _modelCustom = State(initialValue: (!modelValue.isEmpty && !modelIsKnown) ? modelValue : "")

        _yearText = State(initialValue: vehicle.year.map(String.init) ?? "")
        _initialOdoText = State(initialValue: vehicle.initialOdometerKm.map(String.init) ?? "")
        _licensePlate = State(initialValue: vehicle.licensePlate ?? "")
        _vin = State(initialValue: vehicle.vin ?? "")
        let normalizedPlate = TextParsing.normalizeRussianLicensePlate(vehicle.licensePlate ?? "")
        _isLicensePlateInvalid = State(initialValue: normalizedPlate.map { !TextParsing.isValidRussianPrivateCarPlate($0) } ?? false)

        let genValue = (vehicle.generation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let genSuggestions: [String] = {
            let make = makeValue
            let model = modelValue
            let makeIsKnown = VehicleCatalog.isKnownMake(make)
            let models = VehicleCatalog.models(forMake: make)
            let modelIsKnown = models.contains(model)
            guard !make.isEmpty, !model.isEmpty, makeIsKnown, modelIsKnown else { return [] }
            return VehicleCatalog.generations(make: make, model: model)
        }()

        if genValue.isEmpty {
            _selectedGeneration = State(initialValue: "")
            _generationCustom = State(initialValue: "")
            _generationIsCustom = State(initialValue: false)
        } else if genSuggestions.isEmpty {
            _selectedGeneration = State(initialValue: "")
            _generationCustom = State(initialValue: genValue)
            _generationIsCustom = State(initialValue: true)
        } else if genSuggestions.contains(genValue) {
            _selectedGeneration = State(initialValue: genValue)
            _generationCustom = State(initialValue: "")
            _generationIsCustom = State(initialValue: false)
        } else {
            _selectedGeneration = State(initialValue: "__other__")
            _generationCustom = State(initialValue: genValue)
            _generationIsCustom = State(initialValue: true)
        }

        let storedColor = (vehicle.colorName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if storedColor.isEmpty {
            _selectedColor = State(initialValue: "")
            _colorCustom = State(initialValue: "")
            _colorIsCustom = State(initialValue: false)
        } else if VehicleColorOption.allCases.contains(where: { $0.rawValue == storedColor }) {
            _selectedColor = State(initialValue: storedColor)
            _colorCustom = State(initialValue: "")
            _colorIsCustom = State(initialValue: false)
        } else {
            _selectedColor = State(initialValue: "__other__")
            _colorCustom = State(initialValue: storedColor)
            _colorIsCustom = State(initialValue: true)
        }

        let storedEngine = (vehicle.engine ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if storedEngine.isEmpty {
            _selectedEngine = State(initialValue: "")
            _engineCustom = State(initialValue: "")
            _engineIsCustom = State(initialValue: false)
        } else {
            // We'll decide suggestions in-body; default to custom if it doesn't match later.
            _selectedEngine = State(initialValue: storedEngine)
            _engineCustom = State(initialValue: "")
            _engineIsCustom = State(initialValue: false)
        }

        _selectedBodyStyle = State(initialValue: vehicle.bodyStyle ?? "")

        _currentWheelSetChoice = State(initialValue: vehicle.currentWheelSetID?.uuidString ?? "")
        _isWheelSetPickerPresented = State(initialValue: false)
    }

    private var sortedWheelSets: [WheelSet] {
        vehicle.wheelSets.sorted { a, b in
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    private func deleteWheelSet(_ ws: WheelSet) {
        if vehicle.currentWheelSetID == ws.id {
            vehicle.currentWheelSetID = nil
        }
        if currentWheelSetChoice == ws.id.uuidString {
            currentWheelSetChoice = ""
        }

        for e in vehicle.entries {
            if e.wheelSetID == ws.id {
                e.wheelSetID = nil
            }
        }

        vehicle.wheelSets.removeAll { $0.id == ws.id }
        modelContext.delete(ws)
        do { try modelContext.save() } catch { print("Failed to delete wheel set: \(error)") }
    }

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

    private var hasOdometerEntries: Bool {
        vehicle.entries.contains(where: { $0.odometerKm != nil })
    }

    private var currentKmFromEntries: Int? {
        vehicle.entries.compactMap { $0.odometerKm }.max()
    }

    private var currentKm: Int? {
        currentKmFromEntries ?? vehicle.initialOdometerKm
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
                        if !modelIsCustom { modelCustom = "" }

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
                            selectedBodyStyle = (vehicle.bodyStyle?.isEmpty == false ? vehicle.bodyStyle! : (inferredBodyStyle ?? ""))
                        }
                    }

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
                        let storedGen = (vehicle.generation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let genOptions: [String] = {
                            guard isDomesticKnownSelection, !storedGen.isEmpty, !gens.contains(storedGen) else { return gens }
                            return [storedGen] + gens
                        }()
                        Picker(String(localized: "vehicle.field.generation"), selection: $selectedGeneration) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(genOptions, id: \.self) { g in
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
                        let storedEngine = (vehicle.engine ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let engineOptions: [String] = {
                            guard isDomesticKnownSelection, !storedEngine.isEmpty, !engines.contains(storedEngine) else { return engines }
                            return [storedEngine] + engines
                        }()
                        Picker(String(localized: "vehicle.field.engine"), selection: $selectedEngine) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(engineOptions, id: \.self) { e in
                                Text(e).tag(e)
                            }
                            if !isDomesticKnownSelection {
                                Text(String(localized: "vehicle.choice.other")).tag("__other__")
                            }
                        }
                        .onAppear {
                            // If we loaded a stored engine that isn't in suggestions, flip to custom.
                            let stored = (vehicle.engine ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !stored.isEmpty else { return }
                            if engines.contains(stored) {
                                selectedEngine = stored
                                engineCustom = ""
                                engineIsCustom = false
                            } else {
                                if isDomesticKnownSelection {
                                    selectedEngine = stored
                                    engineCustom = ""
                                    engineIsCustom = false
                                } else {
                                    selectedEngine = "__other__"
                                    engineCustom = stored
                                    engineIsCustom = true
                                }
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
                    if let current = currentKm {
                        LabeledContent(String(localized: "vehicle.field.currentOdo"), value: String(current))
                    }

                    TextField(String(localized: "vehicle.field.initialOdo"), text: $initialOdoText)
                        .keyboardType(.numberPad)
                        .disabled(self.hasOdometerEntries)
                }

                Section(String(localized: "vehicle.section.wheels")) {
                    let selectedWheelSet: WheelSet? = {
                        guard !currentWheelSetChoice.isEmpty, let id = UUID(uuidString: currentWheelSetChoice) else { return nil }
                        return vehicle.wheelSets.first(where: { $0.id == id })
                    }()

                    GlassCardRow(isActive: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            if let ws = selectedWheelSet {
                                WheelSetCardContent(
                                    title: ws.autoName,
                                    wheelSpecs: ws.wheelSpecs,
                                    summary: ws.summary
                                )
                            } else {
                                HStack {
                                    Text(String(localized: "vehicle.choice.notSet"))
                                    Spacer()
                                }
                            }

                            Divider()
                                .padding(.vertical, 12)

                            Button {
                                isWheelSetPickerPresented = true
                            } label: {
                                HStack {
                                    Text(String(localized: "wheelSet.action.choose"))
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(String(localized: "vehicle.title.edit"))
            .sheet(isPresented: $isWheelSetPickerPresented) {
                WheelSetPickerSheet(
                    vehicle: vehicle,
                    selection: $currentWheelSetChoice
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        let cleanPlate = TextParsing.normalizeRussianLicensePlate(licensePlate)
                        if let p = cleanPlate, !TextParsing.isValidRussianPrivateCarPlate(p) {
                            isLicensePlateInvalid = true
                            return
                        }

                        let cleanVIN = TextParsing.normalizeVIN(vin)

                        vehicle.name = TextParsing.cleanRequired(name, fallback: String(localized: "vehicle.defaultName"))
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
                        vehicle.make = makeValue
                        vehicle.model = modelValue
                        vehicle.generation = generationValue
                        vehicle.year = TextParsing.parseIntOptional(yearText)
                        vehicle.engine = engineValue
                        vehicle.bodyStyle = bodyStyleValue
                        vehicle.colorName = colorValue
                        if !hasOdometerEntries {
                            vehicle.initialOdometerKm = TextParsing.parseIntOptional(initialOdoText)
                        }
                        vehicle.licensePlate = cleanPlate
                        vehicle.vin = cleanVIN

                        if currentWheelSetChoice.isEmpty {
                            vehicle.currentWheelSetID = nil
                        } else if let id = UUID(uuidString: currentWheelSetChoice) {
                            vehicle.currentWheelSetID = id
                        }

                        do { try modelContext.save() } catch { print("Failed to save vehicle: \(error)") }
                        dismiss()
                    }
                }
            }
        }
    }
}
