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

    private enum WheelSetEditorRoute: Identifiable {
        case add
        case edit(UUID)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let id):
                return "edit_\(id.uuidString)"
            }
        }
    }

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
    @State private var wheelSetEditorRoute: WheelSetEditorRoute?

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
        _wheelSetEditorRoute = State(initialValue: nil)
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
                    }

                    if !sortedWheelSets.isEmpty {
                        ForEach(sortedWheelSets) { ws in
                            HStack(spacing: 10) {
                                Button {
                                    wheelSetEditorRoute = .edit(ws.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ws.name)
                                        if !ws.summary.isEmpty {
                                            Text(ws.summary)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    deleteWheelSet(ws)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button(String(localized: "action.add")) {
                        wheelSetEditorRoute = .add
                    }
                }
            }
            .navigationTitle(String(localized: "vehicle.title.edit"))
            .sheet(item: $wheelSetEditorRoute) { route in
                let wheelSet: WheelSet? = {
                    switch route {
                    case .add:
                        return nil
                    case .edit(let id):
                        return vehicle.wheelSets.first(where: { $0.id == id })
                    }
                }()

                WheelSetEditorSheet(vehicle: vehicle, wheelSet: wheelSet) {
                    currentWheelSetChoice = vehicle.currentWheelSetID?.uuidString ?? ""
                }
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
                        vehicle.initialOdometerKm = TextParsing.parseIntOptional(initialOdoText)
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

private struct WheelSetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle
    let wheelSet: WheelSet?
    let onSaved: () -> Void

    @State private var name: String

    // Tires
    @State private var tireManufacturer: String
    @State private var tireModel: String
    @State private var tireSeasonRaw: String
    /// -1 = not set, 0 = non-studded, 1 = studded
    @State private var tireStuddedChoice: Int
    @State private var tireWidthText: String
    @State private var tireProfileText: String
    @State private var tireDiameter: Int
    @State private var tireSpeedIndex: String
    @State private var tireCount: Int
    @State private var tireYearTexts: [String]

    // Rims
    @State private var rimManufacturer: String
    @State private var rimModel: String
    @State private var rimTypeRaw: String
    @State private var rimDiameter: Int
    @State private var rimWidth: Double
    @State private var rimOffsetET: Int
    @State private var rimCenterBoreText: String
    @State private var rimBoltPattern: String

    private static let rimOffsetNoneToken = -999

    init(vehicle: Vehicle, wheelSet: WheelSet?, onSaved: @escaping () -> Void) {
        self.vehicle = vehicle
        self.wheelSet = wheelSet
        self.onSaved = onSaved

        func parseLegacyTireSize(_ s: String) -> (w: Int, p: Int, d: Int)? {
            let t = s
                .uppercased()
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Examples: "205/55R16", "205/55R16"
            guard let rIdx = t.firstIndex(of: "R") else { return nil }
            let left = String(t[..<rIdx])
            let right = String(t[t.index(after: rIdx)...])
            let parts = left.split(separator: "/", omittingEmptySubsequences: true)
            guard parts.count == 2,
                  let w = Int(parts[0]),
                  let p = Int(parts[1]),
                  let d = Int(right)
            else { return nil }
            return (w, p, d)
        }

        let nameValue = wheelSet?.name ?? ""
        let seasonRawValue = wheelSet?.tireSeasonRaw ?? ""

        let legacyTireSize = (wheelSet?.tireSize ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedLegacy = parseLegacyTireSize(legacyTireSize)

        let initialTireWidth = wheelSet?.tireWidthMM ?? parsedLegacy?.w
        let initialTireProfile = wheelSet?.tireProfile ?? parsedLegacy?.p
        let initialTireDiameter = wheelSet?.tireDiameterInches ?? parsedLegacy?.d

        let studsChoice: Int = {
            if let b = wheelSet?.tireStudded { return b ? 1 : 0 }
            if let wk = wheelSet?.winterTireKindRaw {
                if wk == WinterTireKind.studded.rawValue { return 1 }
                if wk == WinterTireKind.friction.rawValue { return 0 }
            }
            return -1
        }()

        let years = wheelSet?.tireProductionYears ?? []
        var yearTexts = (0..<4).map { idx -> String in
            guard years.indices.contains(idx) else { return "" }
            return years[idx].map(String.init) ?? ""
        }
        if yearTexts.count < 4 { yearTexts.append(contentsOf: Array(repeating: "", count: 4 - yearTexts.count)) }
        if yearTexts.count > 4 { yearTexts = Array(yearTexts.prefix(4)) }

        let rimTypeValue: String = {
            let raw = (wheelSet?.rimTypeRaw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return raw == "steel" ? RimType.stamped.rawValue : raw
        }()

        _name = State(initialValue: nameValue)

        _tireManufacturer = State(initialValue: wheelSet?.tireManufacturer ?? "")
        _tireModel = State(initialValue: wheelSet?.tireModel ?? "")
        _tireSeasonRaw = State(initialValue: seasonRawValue)
        _tireStuddedChoice = State(initialValue: studsChoice)
        _tireWidthText = State(initialValue: initialTireWidth.map(String.init) ?? "")
        _tireProfileText = State(initialValue: initialTireProfile.map(String.init) ?? "")
        _tireDiameter = State(initialValue: initialTireDiameter ?? 0)
        _tireSpeedIndex = State(initialValue: wheelSet?.tireSpeedIndex ?? "")
        _tireCount = State(initialValue: wheelSet?.tireCount ?? 4)
        _tireYearTexts = State(initialValue: yearTexts)

        _rimManufacturer = State(initialValue: wheelSet?.rimManufacturer ?? "")
        _rimModel = State(initialValue: wheelSet?.rimModel ?? "")
        _rimTypeRaw = State(initialValue: rimTypeValue)
        _rimDiameter = State(initialValue: wheelSet?.rimDiameterInches ?? 0)
        _rimWidth = State(initialValue: wheelSet?.rimWidthInches ?? 0)
        _rimOffsetET = State(initialValue: wheelSet?.rimOffsetET ?? Self.rimOffsetNoneToken)
        _rimCenterBoreText = State(initialValue: {
            guard let v = wheelSet?.rimCenterBoreMM else { return "" }
            let isInt = abs(v.rounded() - v) < 0.000_001
            return isInt ? String(Int(v.rounded())) : String(format: "%.1f", v)
        }())
        _rimBoltPattern = State(initialValue: wheelSet?.rimBoltPattern ?? "")
    }

    private var season: TireSeason? {
        tireSeasonRaw.isEmpty ? nil : TireSeason(rawValue: tireSeasonRaw)
    }

    private var isWheelSetValid: Bool {
        let tireBrandOk = TextParsing.cleanOptional(tireManufacturer) != nil
        let tireModelOk = TextParsing.cleanOptional(tireModel) != nil
        let seasonOk = !tireSeasonRaw.isEmpty
        let studsOk: Bool = {
            guard season == .winter else { return true }
            return tireStuddedChoice == 0 || tireStuddedChoice == 1
        }()
        let wOk = TextParsing.parseIntOptional(tireWidthText) != nil
        let pOk = TextParsing.parseIntOptional(tireProfileText) != nil
        let dOk = tireDiameter != 0

        let rimBrandOk = TextParsing.cleanOptional(rimManufacturer) != nil
        let rimModelOk = TextParsing.cleanOptional(rimModel) != nil
        let rimTypeOk = !rimTypeRaw.isEmpty
        let rimDiameterOk = rimDiameter != 0

        return tireBrandOk && tireModelOk && seasonOk && studsOk && wOk && pOk && dOk && rimBrandOk && rimModelOk && rimTypeOk && rimDiameterOk
    }

    private func normalizedTireSizeString(width: Int?, profile: Int?, diameter: Int?) -> String? {
        guard let w = width, let p = profile, let d = diameter else { return nil }
        return "\(w)/\(p) R\(d)"
    }

    private func applySameYearPreset() {
        let visibleCount = (tireCount == 2) ? 2 : 4
        guard visibleCount > 0 else { return }
        let source = tireYearTexts.first ?? ""
        let clean = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        for i in 0..<min(visibleCount, tireYearTexts.count) {
            tireYearTexts[i] = clean
        }
    }

    private func save() {
        let cleanName = TextParsing.cleanRequired(name, fallback: String(localized: "wheelSet.defaultName"))

        let resolvedSeasonRaw: String? = tireSeasonRaw.isEmpty ? nil : tireSeasonRaw
        let resolvedRimTypeRaw: String? = rimTypeRaw.isEmpty ? nil : rimTypeRaw
        let resolvedRimDiameter: Int? = rimDiameter == 0 ? nil : rimDiameter
        let resolvedRimWidth: Double? = rimWidth == 0 ? nil : rimWidth
        let resolvedOffsetET: Int? = rimOffsetET == Self.rimOffsetNoneToken ? nil : rimOffsetET

        let tireWidth = TextParsing.parseIntOptional(tireWidthText)
        let tireProfile = TextParsing.parseIntOptional(tireProfileText)
        let tireDiam = tireDiameter == 0 ? nil : tireDiameter
        let computedTireSize = normalizedTireSizeString(width: tireWidth, profile: tireProfile, diameter: tireDiam)

        let studs: Bool? = {
            guard TireSeason(rawValue: tireSeasonRaw) == .winter else { return nil }
            if tireStuddedChoice == 1 { return true }
            if tireStuddedChoice == 0 { return false }
            return nil
        }()

        let yearCount = (tireCount == 2) ? 2 : 4
        let years: [Int?] = (0..<min(yearCount, tireYearTexts.count)).map { idx in
            TextParsing.parseIntOptional(tireYearTexts[idx])
        }

        let normalizedRimSpec = WheelSpecsCatalog.normalizeWheelSetRimSpec(
            rimType: resolvedRimTypeRaw.flatMap(RimType.init(rawValue:)),
            diameter: resolvedRimDiameter,
            width: resolvedRimWidth,
            offsetET: resolvedOffsetET
        )

        if let ws = wheelSet {
            ws.name = cleanName
            ws.tireSeasonRaw = resolvedSeasonRaw
            ws.tireManufacturer = TextParsing.cleanOptional(tireManufacturer)
            ws.tireModel = TextParsing.cleanOptional(tireModel)
            ws.tireWidthMM = tireWidth
            ws.tireProfile = tireProfile
            ws.tireDiameterInches = tireDiam
            ws.tireSpeedIndex = TextParsing.cleanOptional(tireSpeedIndex)
            ws.tireStudded = studs
            ws.tireCount = tireCount
            ws.tireProductionYears = years

            // Keep legacy helpers in sync.
            ws.tireSize = computedTireSize
            ws.winterTireKindRaw = nil

            ws.rimManufacturer = TextParsing.cleanOptional(rimManufacturer)
            ws.rimModel = TextParsing.cleanOptional(rimModel)
            ws.rimTypeRaw = resolvedRimTypeRaw
            ws.rimDiameterInches = resolvedRimDiameter
            ws.rimWidthInches = resolvedRimWidth
            ws.rimOffsetET = resolvedOffsetET
            ws.rimCenterBoreMM = TextParsing.parseDouble(rimCenterBoreText)
            ws.rimBoltPattern = TextParsing.cleanOptional(rimBoltPattern)
            ws.rimSpec = normalizedRimSpec
        } else {
            let ws = WheelSet(
                name: cleanName,
                tireSeasonRaw: resolvedSeasonRaw,
                rimTypeRaw: resolvedRimTypeRaw,
                rimDiameterInches: resolvedRimDiameter,
                rimWidthInches: resolvedRimWidth,
                rimOffsetET: resolvedOffsetET,
                rimSpec: normalizedRimSpec,
                vehicle: vehicle
            )
            ws.tireManufacturer = TextParsing.cleanOptional(tireManufacturer)
            ws.tireModel = TextParsing.cleanOptional(tireModel)
            ws.tireWidthMM = tireWidth
            ws.tireProfile = tireProfile
            ws.tireDiameterInches = tireDiam
            ws.tireSpeedIndex = TextParsing.cleanOptional(tireSpeedIndex)
            ws.tireStudded = studs
            ws.tireCount = tireCount
            ws.tireProductionYears = years
            ws.tireSize = computedTireSize

            ws.rimManufacturer = TextParsing.cleanOptional(rimManufacturer)
            ws.rimModel = TextParsing.cleanOptional(rimModel)
            ws.rimCenterBoreMM = TextParsing.parseDouble(rimCenterBoreText)
            ws.rimBoltPattern = TextParsing.cleanOptional(rimBoltPattern)

            modelContext.insert(ws)
            vehicle.wheelSets.append(ws)
            vehicle.currentWheelSetID = ws.id
        }

        do { try modelContext.save() } catch { print("Failed to save wheel set: \(error)") }
        onSaved()
        dismiss()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "wheelSet.field.name"), text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section(String(localized: "wheelSet.section.tires")) {
                    TextField(String(localized: "wheelSet.field.tireManufacturer"), text: $tireManufacturer)
                        .textInputAutocapitalization(.words)
                    TextField(String(localized: "wheelSet.field.tireModel"), text: $tireModel)
                        .textInputAutocapitalization(.words)

                    Picker(String(localized: "wheelSet.field.tireSeason"), selection: $tireSeasonRaw) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(TireSeason.allCases) { s in
                            Text(s.title).tag(s.rawValue)
                        }
                    }

                    if TireSeason(rawValue: tireSeasonRaw) == .winter {
                        Picker(String(localized: "wheelSet.field.tireStuds"), selection: $tireStuddedChoice) {
                            Text(String(localized: "vehicle.choice.notSet")).tag(-1)
                            Text(String(localized: "wheelSet.tireStuds.studded")).tag(1)
                            Text(String(localized: "wheelSet.tireStuds.nonStudded")).tag(0)
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        TextField(String(localized: "wheelSet.field.tireWidth"), text: $tireWidthText)
                            .keyboardType(.numberPad)
                        TextField(String(localized: "wheelSet.field.tireProfile"), text: $tireProfileText)
                            .keyboardType(.numberPad)
                    }

                    Picker(String(localized: "wheelSet.field.tireDiameter"), selection: $tireDiameter) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0)
                        ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                            Text("R\(d)").tag(d)
                        }
                    }

                    TextField(String(localized: "wheelSet.field.tireSpeedIndex"), text: $tireSpeedIndex)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Picker(String(localized: "wheelSet.field.tireCount"), selection: $tireCount) {
                        Text("2").tag(2)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.segmented)

                    Button(String(localized: "wheelSet.tireYears.preset.same")) {
                        applySameYearPreset()
                    }
                    .disabled(tireYearTexts.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false)

                    let visibleYears = (tireCount == 2) ? 2 : 4
                    ForEach(0..<visibleYears, id: \.self) { idx in
                        TextField(
                            String.localizedStringWithFormat(String(localized: "wheelSet.field.tireYear"), idx + 1),
                            text: Binding(
                                get: { tireYearTexts.indices.contains(idx) ? tireYearTexts[idx] : "" },
                                set: { newValue in
                                    if tireYearTexts.indices.contains(idx) {
                                        tireYearTexts[idx] = newValue
                                    }
                                }
                            )
                        )
                        .keyboardType(.numberPad)
                    }
                }

                Section(String(localized: "wheelSet.section.rims")) {
                    TextField(String(localized: "wheelSet.field.rimManufacturer"), text: $rimManufacturer)
                        .textInputAutocapitalization(.words)
                    TextField(String(localized: "wheelSet.field.rimModel"), text: $rimModel)
                        .textInputAutocapitalization(.words)

                    Picker(String(localized: "wheelSet.field.rimType"), selection: $rimTypeRaw) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(RimType.allCases) { t in
                            Text(t.title).tag(t.rawValue)
                        }
                    }

                    Picker(String(localized: "wheelSet.field.rimDiameter"), selection: $rimDiameter) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0)
                        ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                            Text("R\(d)").tag(d)
                        }
                    }

                    Picker(String(localized: "wheelSet.field.rimWidth"), selection: $rimWidth) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0.0)
                        ForEach(WheelSpecsCatalog.rimWidthChoices, id: \.self) { w in
                            Text("\(WheelSpecsCatalog.formatWidth(w))J").tag(w)
                        }
                    }

                    Picker(String(localized: "wheelSet.field.rimOffset"), selection: $rimOffsetET) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(Self.rimOffsetNoneToken)
                        ForEach(WheelSpecsCatalog.rimOffsetChoices, id: \.self) { et in
                            Text("ET\(et)").tag(et)
                        }
                    }

                    TextField(String(localized: "wheelSet.field.rimCenterBore"), text: $rimCenterBoreText)
                        .keyboardType(.decimalPad)
                    TextField(String(localized: "wheelSet.field.rimBoltPattern"), text: $rimBoltPattern)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(wheelSet == nil ? String(localized: "action.add") : String(localized: "action.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        save()
                    }
                    .disabled(!isWheelSetValid)
                }
            }
        }
    }
}
