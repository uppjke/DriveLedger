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
    @State private var newWheelSetName: String
    @State private var newWheelSetTireSizeChoice: String
    @State private var newWheelSetTireSizeCustom: String
    @State private var newWheelSetTireSeasonRaw: String
    @State private var newWheelSetWinterKindRaw: String
    @State private var newWheelSetRimTypeRaw: String
    @State private var newWheelSetRimDiameter: Int
    @State private var newWheelSetRimWidth: Double
    @State private var newWheelSetRimOffsetET: Int

    @State private var editingWheelSetID: UUID?
    @State private var editWheelSetName: String
    @State private var editWheelSetTireSizeChoice: String
    @State private var editWheelSetTireSizeCustom: String
    @State private var editWheelSetTireSeasonRaw: String
    @State private var editWheelSetWinterKindRaw: String
    @State private var editWheelSetRimTypeRaw: String
    @State private var editWheelSetRimDiameter: Int
    @State private var editWheelSetRimWidth: Double
    @State private var editWheelSetRimOffsetET: Int

    private static let wheelSetAddToken = "__addWheelSet__"
    private static let wheelSetOtherToken = "__other__"
    private static let rimOffsetNoneToken = -999

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
        _newWheelSetName = State(initialValue: "")
        _newWheelSetTireSizeChoice = State(initialValue: "")
        _newWheelSetTireSizeCustom = State(initialValue: "")
        _newWheelSetTireSeasonRaw = State(initialValue: "")
        _newWheelSetWinterKindRaw = State(initialValue: "")
        _newWheelSetRimTypeRaw = State(initialValue: "")
        _newWheelSetRimDiameter = State(initialValue: 0)
        _newWheelSetRimWidth = State(initialValue: 0)
        _newWheelSetRimOffsetET = State(initialValue: Self.rimOffsetNoneToken)

        _editingWheelSetID = State(initialValue: nil)
        _editWheelSetName = State(initialValue: "")
        _editWheelSetTireSizeChoice = State(initialValue: "")
        _editWheelSetTireSizeCustom = State(initialValue: "")
        _editWheelSetTireSeasonRaw = State(initialValue: "")
        _editWheelSetWinterKindRaw = State(initialValue: "")
        _editWheelSetRimTypeRaw = State(initialValue: "")
        _editWheelSetRimDiameter = State(initialValue: 0)
        _editWheelSetRimWidth = State(initialValue: 0)
        _editWheelSetRimOffsetET = State(initialValue: Self.rimOffsetNoneToken)
    }

    private var sortedWheelSets: [WheelSet] {
        vehicle.wheelSets.sorted { a, b in
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    private var resolvedNewTireSize: String? {
        if newWheelSetTireSizeChoice.isEmpty {
            return nil
        }
        if newWheelSetTireSizeChoice == Self.wheelSetOtherToken {
            return TextParsing.cleanOptional(newWheelSetTireSizeCustom)
        }
        return newWheelSetTireSizeChoice
    }

    private var resolvedNewTireSeasonRaw: String? {
        newWheelSetTireSeasonRaw.isEmpty ? nil : newWheelSetTireSeasonRaw
    }

    private var resolvedNewWinterKindRaw: String? {
        newWheelSetWinterKindRaw.isEmpty ? nil : newWheelSetWinterKindRaw
    }

    private var resolvedNewRimTypeRaw: String? {
        newWheelSetRimTypeRaw.isEmpty ? nil : newWheelSetRimTypeRaw
    }

    private var resolvedNewRimDiameter: Int? {
        newWheelSetRimDiameter == 0 ? nil : newWheelSetRimDiameter
    }

    private var resolvedNewRimWidth: Double? {
        newWheelSetRimWidth == 0 ? nil : newWheelSetRimWidth
    }

    private var resolvedNewRimOffsetET: Int? {
        newWheelSetRimOffsetET == Self.rimOffsetNoneToken ? nil : newWheelSetRimOffsetET
    }

    private func addWheelSetFromDraft() {
        let name = TextParsing.cleanRequired(newWheelSetName, fallback: String(localized: "wheelSet.defaultName"))

        let ws = WheelSet(
            name: name,
            tireSize: resolvedNewTireSize,
            tireSeasonRaw: resolvedNewTireSeasonRaw,
            winterTireKindRaw: resolvedNewWinterKindRaw,
            rimTypeRaw: resolvedNewRimTypeRaw,
            rimDiameterInches: resolvedNewRimDiameter,
            rimWidthInches: resolvedNewRimWidth,
            rimOffsetET: resolvedNewRimOffsetET,
            rimSpec: WheelSpecsCatalog.normalizeWheelSetRimSpec(
                rimType: resolvedNewRimTypeRaw.flatMap(RimType.init(rawValue:)),
                diameter: resolvedNewRimDiameter,
                width: resolvedNewRimWidth,
                offsetET: resolvedNewRimOffsetET
            ),
            vehicle: vehicle
        )
        modelContext.insert(ws)
        vehicle.wheelSets.append(ws)
        vehicle.currentWheelSetID = ws.id

        currentWheelSetChoice = ws.id.uuidString
        newWheelSetName = ""
        newWheelSetTireSizeChoice = ""
        newWheelSetTireSizeCustom = ""
        newWheelSetTireSeasonRaw = ""
        newWheelSetWinterKindRaw = ""
        newWheelSetRimTypeRaw = ""
        newWheelSetRimDiameter = 0
        newWheelSetRimWidth = 0
        newWheelSetRimOffsetET = Self.rimOffsetNoneToken
    }

    private func beginEditingWheelSet(_ ws: WheelSet) {
        editingWheelSetID = ws.id

        editWheelSetName = ws.name

        let size = (ws.tireSize ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if size.isEmpty {
            editWheelSetTireSizeChoice = ""
            editWheelSetTireSizeCustom = ""
        } else if WheelSpecsCatalog.commonTireSizes.contains(size) {
            editWheelSetTireSizeChoice = size
            editWheelSetTireSizeCustom = ""
        } else {
            editWheelSetTireSizeChoice = Self.wheelSetOtherToken
            editWheelSetTireSizeCustom = size
        }

        editWheelSetTireSeasonRaw = ws.tireSeasonRaw ?? ""
        editWheelSetWinterKindRaw = ws.winterTireKindRaw ?? ""

        editWheelSetRimTypeRaw = ws.rimTypeRaw ?? ""
        editWheelSetRimDiameter = ws.rimDiameterInches ?? 0
        editWheelSetRimWidth = ws.rimWidthInches ?? 0
        editWheelSetRimOffsetET = ws.rimOffsetET ?? Self.rimOffsetNoneToken
    }

    private func cancelEditingWheelSet() {
        editingWheelSetID = nil
        editWheelSetName = ""
        editWheelSetTireSizeChoice = ""
        editWheelSetTireSizeCustom = ""
        editWheelSetTireSeasonRaw = ""
        editWheelSetWinterKindRaw = ""
        editWheelSetRimTypeRaw = ""
        editWheelSetRimDiameter = 0
        editWheelSetRimWidth = 0
        editWheelSetRimOffsetET = Self.rimOffsetNoneToken
    }

    private func saveEditedWheelSet() {
        guard let id = editingWheelSetID else { return }
        guard let ws = vehicle.wheelSets.first(where: { $0.id == id }) else { return }

        ws.name = TextParsing.cleanRequired(editWheelSetName, fallback: String(localized: "wheelSet.defaultName"))

        let tireSize: String? = {
            if editWheelSetTireSizeChoice.isEmpty { return nil }
            if editWheelSetTireSizeChoice == Self.wheelSetOtherToken {
                return TextParsing.cleanOptional(editWheelSetTireSizeCustom)
            }
            return editWheelSetTireSizeChoice
        }()

        ws.tireSize = tireSize
        ws.tireSeasonRaw = editWheelSetTireSeasonRaw.isEmpty ? nil : editWheelSetTireSeasonRaw

        let season = TireSeason(rawValue: editWheelSetTireSeasonRaw)
        if season == .winter {
            ws.winterTireKindRaw = editWheelSetWinterKindRaw.isEmpty ? nil : editWheelSetWinterKindRaw
        } else {
            ws.winterTireKindRaw = nil
            editWheelSetWinterKindRaw = ""
        }

        ws.rimTypeRaw = editWheelSetRimTypeRaw.isEmpty ? nil : editWheelSetRimTypeRaw
        ws.rimDiameterInches = editWheelSetRimDiameter == 0 ? nil : editWheelSetRimDiameter
        ws.rimWidthInches = editWheelSetRimWidth == 0 ? nil : editWheelSetRimWidth
        ws.rimOffsetET = editWheelSetRimOffsetET == Self.rimOffsetNoneToken ? nil : editWheelSetRimOffsetET
        ws.rimSpec = WheelSpecsCatalog.normalizeWheelSetRimSpec(
            rimType: ws.rimType,
            diameter: ws.rimDiameterInches,
            width: ws.rimWidthInches,
            offsetET: ws.rimOffsetET
        )

        do { try modelContext.save() } catch { print("Failed to save wheel set: \(error)") }
        cancelEditingWheelSet()
    }

    private func deleteWheelSet(_ ws: WheelSet) {
        if editingWheelSetID == ws.id {
            cancelEditingWheelSet()
        }

        if vehicle.currentWheelSetID == ws.id {
            vehicle.currentWheelSetID = nil
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
                    TextField(String(localized: "vehicle.field.initialOdo"), text: $initialOdoText)
                        .keyboardType(.numberPad)
                }

                Section(String(localized: "vehicle.section.wheels")) {
                    Picker(String(localized: "vehicle.field.currentWheelSet"), selection: $currentWheelSetChoice) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(sortedWheelSets) { ws in
                            Text(ws.name).tag(ws.id.uuidString)
                        }
                        Text(String(localized: "wheelSet.choice.addNew")).tag(Self.wheelSetAddToken)
                    }

                    if currentWheelSetChoice == Self.wheelSetAddToken {
                        TextField(String(localized: "wheelSet.field.name"), text: $newWheelSetName)
                            .textInputAutocapitalization(.words)

                        Picker(String(localized: "wheelSet.field.tireSize"), selection: $newWheelSetTireSizeChoice) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(WheelSpecsCatalog.commonTireSizes, id: \.self) { s in
                                Text(s).tag(s)
                            }
                            Text(String(localized: "wheelSet.choice.other")).tag(Self.wheelSetOtherToken)
                        }
                        if newWheelSetTireSizeChoice == Self.wheelSetOtherToken {
                            TextField(String(localized: "wheelSet.field.tireSize"), text: $newWheelSetTireSizeCustom)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }

                        Picker(String(localized: "wheelSet.field.tireSeason"), selection: $newWheelSetTireSeasonRaw) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(TireSeason.allCases) { s in
                                Text(s.title).tag(s.rawValue)
                            }
                        }
                        if TireSeason(rawValue: newWheelSetTireSeasonRaw) == .winter {
                            Picker(String(localized: "wheelSet.field.winterKind"), selection: $newWheelSetWinterKindRaw) {
                                Text(String(localized: "vehicle.choice.notSet")).tag("")
                                ForEach(WinterTireKind.allCases) { k in
                                    Text(k.title).tag(k.rawValue)
                                }
                            }
                        }

                        Picker(String(localized: "wheelSet.field.rimType"), selection: $newWheelSetRimTypeRaw) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(RimType.allCases) { t in
                                Text(t.title).tag(t.rawValue)
                            }
                        }

                        Picker(String(localized: "wheelSet.field.rimDiameter"), selection: $newWheelSetRimDiameter) {
                            Text(String(localized: "vehicle.choice.notSet")).tag(0)
                            ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                                Text("R\(d)").tag(d)
                            }
                        }

                        Picker(String(localized: "wheelSet.field.rimWidth"), selection: $newWheelSetRimWidth) {
                            Text(String(localized: "vehicle.choice.notSet")).tag(0.0)
                            ForEach(WheelSpecsCatalog.rimWidthChoices, id: \.self) { w in
                                Text("\(WheelSpecsCatalog.formatWidth(w))J").tag(w)
                            }
                        }

                        Picker(String(localized: "wheelSet.field.rimOffset"), selection: $newWheelSetRimOffsetET) {
                            Text(String(localized: "vehicle.choice.notSet")).tag(Self.rimOffsetNoneToken)
                            ForEach(WheelSpecsCatalog.rimOffsetChoices, id: \.self) { et in
                                Text("ET\(et)").tag(et)
                            }
                        }

                        Button(String(localized: "action.add")) {
                            addWheelSetFromDraft()
                        }
                    }

                    if !sortedWheelSets.isEmpty {
                        ForEach(sortedWheelSets) { ws in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ws.name)
                                if !ws.summary.isEmpty {
                                    Text(ws.summary)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    beginEditingWheelSet(ws)
                                } label: {
                                    Label(String(localized: "action.edit"), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    deleteWheelSet(ws)
                                } label: {
                                    Label(String(localized: "action.delete"), systemImage: "trash")
                                }
                            }
                        }
                    }

                    if let id = editingWheelSetID,
                       vehicle.wheelSets.contains(where: { $0.id == id }) {
                        Divider()

                        TextField(String(localized: "wheelSet.field.name"), text: $editWheelSetName)
                            .textInputAutocapitalization(.words)

                        Picker(String(localized: "wheelSet.field.tireSize"), selection: $editWheelSetTireSizeChoice) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(WheelSpecsCatalog.commonTireSizes, id: \.self) { s in
                                Text(s).tag(s)
                            }
                            Text(String(localized: "wheelSet.choice.other")).tag(Self.wheelSetOtherToken)
                        }
                        if editWheelSetTireSizeChoice == Self.wheelSetOtherToken {
                            TextField(String(localized: "wheelSet.field.tireSize"), text: $editWheelSetTireSizeCustom)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }

                        Picker(String(localized: "wheelSet.field.tireSeason"), selection: $editWheelSetTireSeasonRaw) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(TireSeason.allCases) { s in
                                Text(s.title).tag(s.rawValue)
                            }
                        }
                        if TireSeason(rawValue: editWheelSetTireSeasonRaw) == .winter {
                            Picker(String(localized: "wheelSet.field.winterKind"), selection: $editWheelSetWinterKindRaw) {
                                Text(String(localized: "vehicle.choice.notSet")).tag("")
                                ForEach(WinterTireKind.allCases) { k in
                                    Text(k.title).tag(k.rawValue)
                                }
                            }
                        }

                        Picker(String(localized: "wheelSet.field.rimType"), selection: $editWheelSetRimTypeRaw) {
                            Text(String(localized: "vehicle.choice.notSet")).tag("")
                            ForEach(RimType.allCases) { t in
                                Text(t.title).tag(t.rawValue)
                            }
                        }

                        Picker(String(localized: "wheelSet.field.rimDiameter"), selection: $editWheelSetRimDiameter) {
                            Text(String(localized: "vehicle.choice.notSet")).tag(0)
                            ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                                Text("R\(d)").tag(d)
                            }
                        }

                        Picker(String(localized: "wheelSet.field.rimWidth"), selection: $editWheelSetRimWidth) {
                            Text(String(localized: "vehicle.choice.notSet")).tag(0.0)
                            ForEach(WheelSpecsCatalog.rimWidthChoices, id: \.self) { w in
                                Text("\(WheelSpecsCatalog.formatWidth(w))J").tag(w)
                            }
                        }

                        Picker(String(localized: "wheelSet.field.rimOffset"), selection: $editWheelSetRimOffsetET) {
                            Text(String(localized: "vehicle.choice.notSet")).tag(Self.rimOffsetNoneToken)
                            ForEach(WheelSpecsCatalog.rimOffsetChoices, id: \.self) { et in
                                Text("ET\(et)").tag(et)
                            }
                        }

                        HStack {
                            Button(String(localized: "action.cancel")) {
                                cancelEditingWheelSet()
                            }
                            Spacer()
                            Button(String(localized: "action.save")) {
                                saveEditedWheelSet()
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "vehicle.title.edit"))
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
                        vehicle.initialOdometerKm = TextParsing.parseIntOptional(initialOdoText)
                        vehicle.licensePlate = cleanPlate
                        vehicle.vin = cleanVIN

                        if currentWheelSetChoice.isEmpty {
                            vehicle.currentWheelSetID = nil
                        } else if currentWheelSetChoice != Self.wheelSetAddToken,
                                  let id = UUID(uuidString: currentWheelSetChoice) {
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
