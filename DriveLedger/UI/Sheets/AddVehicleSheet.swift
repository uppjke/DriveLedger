//
//  AddVehicleSheet.swift
//  DriveLedger
//

import SwiftUI
import Foundation

struct AddVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss

    private enum WheelSetEditorRoute: Identifiable {
        case add
        case edit(UUID)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let id):
                return "edit-\(id.uuidString)"
            }
        }
    }

    fileprivate struct WheelSetDraft: Identifiable, Equatable {
        var id: UUID = UUID()
        var name: String = ""

        // Tires
        var tireManufacturer: String = ""
        var tireModel: String = ""
        var tireSeasonRaw: String = ""
        /// -1 = not set, 0 = non-studded, 1 = studded
        var tireStuddedChoice: Int = -1
        var tireWidthText: String = ""
        var tireProfileText: String = ""
        var tireDiameter: Int = 0
        var tireSpeedIndex: String = ""
        var tireCount: Int = 4
        var tireYearTexts: [String] = ["", "", "", ""]

        // Rims
        var rimManufacturer: String = ""
        var rimModel: String = ""
        var rimTypeRaw: String = ""
        var rimDiameter: Int = 0
        var rimWidth: Double = 0
        var rimOffsetET: Int = AddVehicleSheetWheelSetEditor.rimOffsetNoneToken
        var rimCenterBoreText: String = ""
        var rimBoltPattern: String = ""

        var summary: String {
            func clean(_ s: String) -> String? { TextParsing.cleanOptional(s) }

            var tireParts: [String] = []
            if let w = TextParsing.parseIntOptional(tireWidthText),
               let p = TextParsing.parseIntOptional(tireProfileText),
               tireDiameter != 0 {
                tireParts.append("\(w)/\(p) R\(tireDiameter)")
            }

            let tm = [clean(tireManufacturer), clean(tireModel)].compactMap { $0 }.joined(separator: " ")
            if !tm.isEmpty { tireParts.append(tm) }

            if let season = TireSeason(rawValue: tireSeasonRaw) {
                tireParts.append(season.title)
                if season == .winter {
                    if tireStuddedChoice == 1 {
                        tireParts.append(String(localized: "wheelSet.tireStuds.studded"))
                    } else if tireStuddedChoice == 0 {
                        tireParts.append(String(localized: "wheelSet.tireStuds.nonStudded"))
                    }
                }
            }

            if let si = clean(tireSpeedIndex) {
                tireParts.append(si.uppercased())
            }

            var rimParts: [String] = []
            let rm = [clean(rimManufacturer), clean(rimModel)].compactMap { $0 }.joined(separator: " ")
            if !rm.isEmpty { rimParts.append(rm) }
            if let t = RimType(rawValue: rimTypeRaw) {
                rimParts.append(t.title)
            }
            if rimDiameter != 0 { rimParts.append("R\(rimDiameter)") }
            if rimWidth != 0 { rimParts.append("\(WheelSpecsCatalog.formatWidth(rimWidth))J") }
            if rimOffsetET != AddVehicleSheetWheelSetEditor.rimOffsetNoneToken {
                rimParts.append("ET\(rimOffsetET)")
            }
            if let pcd = clean(rimBoltPattern) {
                rimParts.append("PCD \(pcd)")
            }
            if let dia = TextParsing.parseDouble(rimCenterBoreText) {
                let isInt = abs(dia.rounded() - dia) < 0.000_001
                let t = isInt ? String(Int(dia.rounded())) : String(format: "%.1f", dia)
                rimParts.append("DIA \(t)")
            }

            let parts = [
                tireParts.joined(separator: " · "),
                rimParts.joined(separator: " ")
            ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            return parts.joined(separator: " · ")
        }
    }

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

    @State private var wheelSetEditorRoute: WheelSetEditorRoute?
    @State private var wheelSetDrafts: [WheelSetDraft] = []
    @State private var currentWheelSetDraftID: UUID?

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

                Section(String(localized: "vehicle.section.wheels")) {
                    Picker(String(localized: "vehicle.field.currentWheelSet"), selection: Binding(
                        get: { currentWheelSetDraftID?.uuidString ?? "" },
                        set: { newValue in
                            currentWheelSetDraftID = newValue.isEmpty ? nil : UUID(uuidString: newValue)
                        }
                    )) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(wheelSetDrafts) { ws in
                            Text(ws.name.isEmpty ? String(localized: "wheelSet.defaultName") : ws.name).tag(ws.id.uuidString)
                        }
                    }

                    if !wheelSetDrafts.isEmpty {
                        ForEach(wheelSetDrafts) { ws in
                            HStack(spacing: 10) {
                                Button {
                                    wheelSetEditorRoute = .edit(ws.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ws.name.isEmpty ? String(localized: "wheelSet.defaultName") : ws.name)
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
                                    if currentWheelSetDraftID == ws.id {
                                        currentWheelSetDraftID = nil
                                    }
                                    wheelSetDrafts.removeAll { $0.id == ws.id }
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
            .navigationTitle(String(localized: "vehicle.title.new"))
            .sheet(item: $wheelSetEditorRoute) { route in
                let draftBinding: Binding<WheelSetDraft?> = Binding(
                    get: {
                        switch route {
                        case .add:
                            return nil
                        case .edit(let id):
                            return wheelSetDrafts.first(where: { $0.id == id })
                        }
                    },
                    set: { newValue in
                        switch route {
                        case .add:
                            if let d = newValue {
                                wheelSetDrafts.append(d)
                                currentWheelSetDraftID = currentWheelSetDraftID ?? d.id
                            }
                        case .edit(let id):
                            guard let d = newValue else { return }
                            if let idx = wheelSetDrafts.firstIndex(where: { $0.id == id }) {
                                wheelSetDrafts[idx] = d
                            }
                        }
                    }
                )

                AddVehicleSheetWheelSetEditor(draft: draftBinding)
            }
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

                        // Materialize wheel sets from drafts.
                        for draft in wheelSetDrafts {
                            let ws = WheelSet(
                                id: draft.id,
                                name: TextParsing.cleanRequired(draft.name, fallback: String(localized: "wheelSet.defaultName")),
                                tireSeasonRaw: draft.tireSeasonRaw.isEmpty ? nil : draft.tireSeasonRaw,
                                rimTypeRaw: draft.rimTypeRaw.isEmpty ? nil : draft.rimTypeRaw,
                                rimDiameterInches: draft.rimDiameter == 0 ? nil : draft.rimDiameter,
                                rimWidthInches: draft.rimWidth == 0 ? nil : draft.rimWidth,
                                rimOffsetET: draft.rimOffsetET == AddVehicleSheetWheelSetEditor.rimOffsetNoneToken ? nil : draft.rimOffsetET,
                                rimSpec: WheelSpecsCatalog.normalizeWheelSetRimSpec(
                                    rimType: draft.rimTypeRaw.isEmpty ? nil : RimType(rawValue: draft.rimTypeRaw),
                                    diameter: draft.rimDiameter == 0 ? nil : draft.rimDiameter,
                                    width: draft.rimWidth == 0 ? nil : draft.rimWidth,
                                    offsetET: draft.rimOffsetET == AddVehicleSheetWheelSetEditor.rimOffsetNoneToken ? nil : draft.rimOffsetET
                                ),
                                vehicle: v
                            )

                            let tireWidth = TextParsing.parseIntOptional(draft.tireWidthText)
                            let tireProfile = TextParsing.parseIntOptional(draft.tireProfileText)
                            let tireDiam = draft.tireDiameter == 0 ? nil : draft.tireDiameter
                            ws.tireManufacturer = TextParsing.cleanOptional(draft.tireManufacturer)
                            ws.tireModel = TextParsing.cleanOptional(draft.tireModel)
                            ws.tireWidthMM = tireWidth
                            ws.tireProfile = tireProfile
                            ws.tireDiameterInches = tireDiam
                            ws.tireSpeedIndex = TextParsing.cleanOptional(draft.tireSpeedIndex)
                            ws.tireStudded = {
                                guard TireSeason(rawValue: draft.tireSeasonRaw) == .winter else { return nil }
                                if draft.tireStuddedChoice == 1 { return true }
                                if draft.tireStuddedChoice == 0 { return false }
                                return nil
                            }()
                            ws.tireCount = draft.tireCount
                            let yearCount = (draft.tireCount == 2) ? 2 : 4
                            ws.tireProductionYears = (0..<min(yearCount, draft.tireYearTexts.count)).map { idx in
                                TextParsing.parseIntOptional(draft.tireYearTexts[idx])
                            }
                            ws.tireSize = {
                                guard let w = tireWidth, let p = tireProfile, let d = tireDiam else { return nil }
                                return "\(w)/\(p) R\(d)"
                            }()
                            ws.winterTireKindRaw = nil

                            ws.rimManufacturer = TextParsing.cleanOptional(draft.rimManufacturer)
                            ws.rimModel = TextParsing.cleanOptional(draft.rimModel)
                            ws.rimBoltPattern = TextParsing.cleanOptional(draft.rimBoltPattern)
                            ws.rimCenterBoreMM = TextParsing.parseDouble(draft.rimCenterBoreText)

                            v.wheelSets.append(ws)
                        }

                        if let cur = currentWheelSetDraftID {
                            v.currentWheelSetID = cur
                        }

                        onCreate(v)
                        dismiss()
                    }
                    .disabled((TextParsing.cleanOptional(name) == nil && TextParsing.cleanOptional(licensePlate) == nil && selectedMake.isEmpty && makeCustom.isEmpty) || isLicensePlateInvalid)
                }
            }
        }
    }
}

private struct AddVehicleSheetWheelSetEditor: View {
    @Environment(\.dismiss) private var dismiss

    static let rimOffsetNoneToken = -999

    @Binding var draft: AddVehicleSheet.WheelSetDraft?

    @State private var working: AddVehicleSheet.WheelSetDraft

    init(draft: Binding<AddVehicleSheet.WheelSetDraft?>) {
        _draft = draft
        _working = State(initialValue: draft.wrappedValue ?? .init())
    }

    private var season: TireSeason? {
        working.tireSeasonRaw.isEmpty ? nil : TireSeason(rawValue: working.tireSeasonRaw)
    }

    private var isValid: Bool {
        let tireBrandOk = TextParsing.cleanOptional(working.tireManufacturer) != nil
        let tireModelOk = TextParsing.cleanOptional(working.tireModel) != nil
        let seasonOk = !working.tireSeasonRaw.isEmpty
        let studsOk: Bool = {
            guard season == .winter else { return true }
            return working.tireStuddedChoice == 0 || working.tireStuddedChoice == 1
        }()
        let wOk = TextParsing.parseIntOptional(working.tireWidthText) != nil
        let pOk = TextParsing.parseIntOptional(working.tireProfileText) != nil
        let dOk = working.tireDiameter != 0

        let rimBrandOk = TextParsing.cleanOptional(working.rimManufacturer) != nil
        let rimModelOk = TextParsing.cleanOptional(working.rimModel) != nil
        let rimTypeOk = !working.rimTypeRaw.isEmpty
        let rimDiameterOk = working.rimDiameter != 0

        return tireBrandOk && tireModelOk && seasonOk && studsOk && wOk && pOk && dOk && rimBrandOk && rimModelOk && rimTypeOk && rimDiameterOk
    }

    private func applySameYearPreset() {
        let visibleCount = (working.tireCount == 2) ? 2 : 4
        guard visibleCount > 0 else { return }
        let source = working.tireYearTexts.first ?? ""
        let clean = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        for i in 0..<min(visibleCount, working.tireYearTexts.count) {
            working.tireYearTexts[i] = clean
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "wheelSet.field.name"), text: $working.name)
                        .textInputAutocapitalization(.words)
                }

                Section(String(localized: "wheelSet.section.tires")) {
                    TextField(String(localized: "wheelSet.field.tireManufacturer"), text: $working.tireManufacturer)
                        .textInputAutocapitalization(.words)
                    TextField(String(localized: "wheelSet.field.tireModel"), text: $working.tireModel)
                        .textInputAutocapitalization(.words)

                    Picker(String(localized: "wheelSet.field.tireSeason"), selection: $working.tireSeasonRaw) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(TireSeason.allCases) { s in
                            Text(s.title).tag(s.rawValue)
                        }
                    }

                    if season == .winter {
                        Picker(String(localized: "wheelSet.field.tireStuds"), selection: $working.tireStuddedChoice) {
                            Text(String(localized: "vehicle.choice.notSet")).tag(-1)
                            Text(String(localized: "wheelSet.tireStuds.studded")).tag(1)
                            Text(String(localized: "wheelSet.tireStuds.nonStudded")).tag(0)
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        TextField(String(localized: "wheelSet.field.tireWidth"), text: $working.tireWidthText)
                            .keyboardType(.numberPad)
                        TextField(String(localized: "wheelSet.field.tireProfile"), text: $working.tireProfileText)
                            .keyboardType(.numberPad)
                    }

                    Picker(String(localized: "wheelSet.field.tireDiameter"), selection: $working.tireDiameter) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0)
                        ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                            Text("R\(d)").tag(d)
                        }
                    }

                    TextField(String(localized: "wheelSet.field.tireSpeedIndex"), text: $working.tireSpeedIndex)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Picker(String(localized: "wheelSet.field.tireCount"), selection: $working.tireCount) {
                        Text("2").tag(2)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.segmented)

                    Button(String(localized: "wheelSet.tireYears.preset.same")) {
                        applySameYearPreset()
                    }
                    .disabled(working.tireYearTexts.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false)

                    let visibleYears = (working.tireCount == 2) ? 2 : 4
                    ForEach(0..<visibleYears, id: \.self) { idx in
                        TextField(
                            String.localizedStringWithFormat(String(localized: "wheelSet.field.tireYear"), idx + 1),
                            text: Binding(
                                get: { working.tireYearTexts.indices.contains(idx) ? working.tireYearTexts[idx] : "" },
                                set: { newValue in
                                    if working.tireYearTexts.indices.contains(idx) {
                                        working.tireYearTexts[idx] = newValue
                                    }
                                }
                            )
                        )
                        .keyboardType(.numberPad)
                    }
                }

                Section(String(localized: "wheelSet.section.rims")) {
                    TextField(String(localized: "wheelSet.field.rimManufacturer"), text: $working.rimManufacturer)
                        .textInputAutocapitalization(.words)
                    TextField(String(localized: "wheelSet.field.rimModel"), text: $working.rimModel)
                        .textInputAutocapitalization(.words)

                    Picker(String(localized: "wheelSet.field.rimType"), selection: $working.rimTypeRaw) {
                        Text(String(localized: "vehicle.choice.notSet")).tag("")
                        ForEach(RimType.allCases) { t in
                            Text(t.title).tag(t.rawValue)
                        }
                    }

                    Picker(String(localized: "wheelSet.field.rimDiameter"), selection: $working.rimDiameter) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0)
                        ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                            Text("R\(d)").tag(d)
                        }
                    }

                    Picker(String(localized: "wheelSet.field.rimWidth"), selection: $working.rimWidth) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0.0)
                        ForEach(WheelSpecsCatalog.rimWidthChoices, id: \.self) { w in
                            Text("\(WheelSpecsCatalog.formatWidth(w))J").tag(w)
                        }
                    }

                    Picker(String(localized: "wheelSet.field.rimOffset"), selection: $working.rimOffsetET) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(Self.rimOffsetNoneToken)
                        ForEach(WheelSpecsCatalog.rimOffsetChoices, id: \.self) { et in
                            Text("ET\(et)").tag(et)
                        }
                    }

                    TextField(String(localized: "wheelSet.field.rimCenterBore"), text: $working.rimCenterBoreText)
                        .keyboardType(.decimalPad)
                    TextField(String(localized: "wheelSet.field.rimBoltPattern"), text: $working.rimBoltPattern)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(String(localized: "action.add"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        draft = working
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

