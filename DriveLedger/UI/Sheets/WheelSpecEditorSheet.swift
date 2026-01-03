import SwiftUI

struct WheelSpecDraft: Equatable {
    var tireManufacturer: String = ""
    var tireModel: String = ""
    var tireSeasonRaw: String = ""
    var tireStudded: Bool = false
    var tireWidthText: String = ""
    var tireProfileText: String = ""
    var tireDiameterInches: Int = 0
    var tireSpeedIndex: String = ""
    var tireLoadIndex: String = ""
    var tireProductionYearText: String = ""

    var rimManufacturer: String = ""
    var rimModel: String = ""

    var rimTypeRaw: String = ""
    var rimDiameterInches: Int = 0
    var rimWidthInches: Double = 0
    var rimOffsetET: Int = 0
    var rimCenterBoreText: String = ""
    var rimBoltPattern: String = ""
}

struct WheelSpecEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WheelSpecDraft
    private let prefillOptions: [WheelSpec]
    let onSaved: (WheelSpec) -> Void

    init(
        draft: WheelSpecDraft = WheelSpecDraft(),
        prefillOptions: [WheelSpec] = [],
        onSaved: @escaping (WheelSpec) -> Void
    ) {
        var normalizedDraft = draft
        if TireSeason(rawValue: normalizedDraft.tireSeasonRaw) == nil {
            normalizedDraft.tireSeasonRaw = TireSeason.summer.rawValue
        }
        if RimType(rawValue: normalizedDraft.rimTypeRaw) == nil {
            normalizedDraft.rimTypeRaw = RimType.alloy.rawValue
        }
        _draft = State(initialValue: normalizedDraft)
        self.prefillOptions = prefillOptions
        self.onSaved = onSaved
    }

    private var uniquePrefillOptions: [WheelSpec] {
        var seen = Set<String>()
        var result: [WheelSpec] = []
        for spec in prefillOptions {
            if seen.insert(spec.dedupKey).inserted {
                result.append(spec)
            }
        }
        return result
    }

    private var isValid: Bool {
        let tireBrandOk = TextParsing.cleanOptional(draft.tireManufacturer) != nil
        let seasonOk = TireSeason(rawValue: draft.tireSeasonRaw) != nil
        let wOk = TextParsing.parseIntOptional(draft.tireWidthText) != nil
        let pOk = TextParsing.parseIntOptional(draft.tireProfileText) != nil
        let dOk = draft.tireDiameterInches != 0

        let rimBrandOk = TextParsing.cleanOptional(draft.rimManufacturer) != nil
        let rimTypeOk = RimType(rawValue: draft.rimTypeRaw) != nil
        let rimDOk = draft.rimDiameterInches != 0

        return tireBrandOk && seasonOk && wOk && pOk && dOk && rimBrandOk && rimTypeOk && rimDOk
    }

    private func save() {
        guard isValid,
              let tireBrand = TextParsing.cleanOptional(draft.tireManufacturer),
              let season = TireSeason(rawValue: draft.tireSeasonRaw),
              let w = TextParsing.parseIntOptional(draft.tireWidthText),
              let p = TextParsing.parseIntOptional(draft.tireProfileText)
        else { return }

        guard let rimBrand = TextParsing.cleanOptional(draft.rimManufacturer),
              let rimType = RimType(rawValue: draft.rimTypeRaw)
        else { return }

        let tireModel = TextParsing.cleanOptional(draft.tireModel)
        let rimModel = TextParsing.cleanOptional(draft.rimModel)

        let speedIndex = TextParsing.cleanOptional(draft.tireSpeedIndex)
        let loadIndex = TextParsing.cleanOptional(draft.tireLoadIndex)
        let productionYear = TextParsing.parseIntOptional(draft.tireProductionYearText)

        let studs: Bool? = {
            guard season == .winter else { return nil }
            return draft.tireStudded
        }()

        let rimWidth: Double? = draft.rimWidthInches == 0 ? nil : draft.rimWidthInches
        let rimOffset: Int? = draft.rimOffsetET == 0 ? nil : draft.rimOffsetET
        let rimCenterBore: Double? = TextParsing.parseDouble(draft.rimCenterBoreText)
        let rimBoltPattern = TextParsing.cleanOptional(draft.rimBoltPattern)

        let spec = WheelSpec(
            tireManufacturer: tireBrand,
            tireModel: tireModel,
            tireSeason: season,
            tireStudded: studs,
            tireWidthMM: w,
            tireProfile: p,
            tireDiameterInches: draft.tireDiameterInches,
            tireSpeedIndex: speedIndex,
            tireLoadIndex: loadIndex,
            tireProductionYear: productionYear,
            rimManufacturer: rimBrand,
            rimModel: rimModel,
            rimDiameterInches: draft.rimDiameterInches,
            rimType: rimType,
            rimWidthInches: rimWidth,
            rimOffsetET: rimOffset,
            rimCenterBoreMM: rimCenterBore,
            rimBoltPattern: rimBoltPattern
        )

        onSaved(spec)
        dismiss()
    }

    private func applyPrefill(from spec: WheelSpec) {
        draft.tireManufacturer = spec.tireManufacturer
        draft.tireModel = spec.tireModel ?? ""
        draft.tireSeasonRaw = spec.tireSeason?.rawValue ?? TireSeason.summer.rawValue
        draft.tireStudded = spec.tireStudded ?? false
        draft.tireWidthText = String(spec.tireWidthMM)
        draft.tireProfileText = String(spec.tireProfile)
        draft.tireDiameterInches = spec.tireDiameterInches
        draft.tireSpeedIndex = spec.tireSpeedIndex ?? ""
        draft.tireLoadIndex = spec.tireLoadIndex ?? ""
        draft.tireProductionYearText = spec.tireProductionYear.map(String.init) ?? ""
        draft.rimManufacturer = spec.rimManufacturer
        draft.rimModel = spec.rimModel ?? ""
        draft.rimTypeRaw = spec.rimType?.rawValue ?? RimType.alloy.rawValue
        draft.rimDiameterInches = spec.rimDiameterInches
        draft.rimWidthInches = spec.rimWidthInches ?? 0
        draft.rimOffsetET = spec.rimOffsetET ?? 0
        draft.rimCenterBoreText = spec.rimCenterBoreMM.map { v in
            let isInt = abs(v.rounded() - v) < 0.000_001
            return isInt ? String(Int(v.rounded())) : String(format: "%.1f", v)
        } ?? ""
        draft.rimBoltPattern = spec.rimBoltPattern ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                if !uniquePrefillOptions.isEmpty {
                    Section(String(localized: "wheelSpec.prefill.section")) {
                        Menu {
                            ForEach(uniquePrefillOptions) { spec in
                                Button {
                                    applyPrefill(from: spec)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(spec.tireDisplay)
                                        Text(spec.rimDisplay)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            Label(String(localized: "wheelSpec.prefill.action"), systemImage: "doc.on.doc")
                        }
                    }
                }

                Section(String(localized: "wheelSet.section.tires")) {
                    TextField(String(localized: "wheelSet.field.tireManufacturer"), text: $draft.tireManufacturer)
                        .textInputAutocapitalization(.words)

                    TextField(String(localized: "wheelSet.field.tireModel"), text: $draft.tireModel)
                        .textInputAutocapitalization(.words)

                    Picker(String(localized: "wheelSet.field.tireSeason"), selection: $draft.tireSeasonRaw) {
                        ForEach(TireSeason.allCases) { s in
                            Text(s.title).tag(s.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    if TireSeason(rawValue: draft.tireSeasonRaw) == .winter {
                        Toggle(String(localized: "wheelSet.field.tireStuds"), isOn: $draft.tireStudded)
                    }

                    HStack {
                        TextField(String(localized: "wheelSet.field.tireWidth"), text: $draft.tireWidthText)
                            .keyboardType(.numberPad)
                        TextField(String(localized: "wheelSet.field.tireProfile"), text: $draft.tireProfileText)
                            .keyboardType(.numberPad)
                    }

                    Picker(String(localized: "wheelSet.field.tireDiameter"), selection: $draft.tireDiameterInches) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0)
                        ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                            Text("R\(d)").tag(d)
                        }
                    }

                    TextField(String(localized: "wheelSet.field.tireLoadIndex"), text: $draft.tireLoadIndex)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField(String(localized: "wheelSet.field.tireSpeedIndex"), text: $draft.tireSpeedIndex)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField(String(localized: "wheelSet.field.tireProductionYear"), text: $draft.tireProductionYearText)
                        .keyboardType(.numberPad)
                }

                Section(String(localized: "wheelSet.section.rims")) {
                    TextField(String(localized: "wheelSet.field.rimManufacturer"), text: $draft.rimManufacturer)
                        .textInputAutocapitalization(.words)

                    TextField(String(localized: "wheelSet.field.rimModel"), text: $draft.rimModel)
                        .textInputAutocapitalization(.words)

                    Picker(String(localized: "wheelSet.field.rimType"), selection: $draft.rimTypeRaw) {
                        ForEach(RimType.allCases) { t in
                            Text(t.title).tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(String(localized: "wheelSet.field.rimDiameter"), selection: $draft.rimDiameterInches) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0)
                        ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                            Text("R\(d)").tag(d)
                        }
                    }

                    Picker(String(localized: "wheelSet.field.rimWidth"), selection: $draft.rimWidthInches) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0.0)
                        ForEach(WheelSpecsCatalog.rimWidthChoices, id: \.self) { w in
                            Text("\(WheelSpecsCatalog.formatWidth(w))J").tag(w)
                        }
                    }

                    Picker(String(localized: "wheelSet.field.rimOffset"), selection: $draft.rimOffsetET) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0)
                        ForEach(WheelSpecsCatalog.rimOffsetChoices, id: \.self) { et in
                            Text("ET\(et)").tag(et)
                        }
                    }

                    TextField(String(localized: "wheelSet.field.rimCenterBore"), text: $draft.rimCenterBoreText)
                        .keyboardType(.decimalPad)

                    TextField(String(localized: "wheelSet.field.rimBoltPattern"), text: $draft.rimBoltPattern)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(String(localized: "wheelSpec.editor.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                        .disabled(!isValid)
                }
            }
        }
    }
}
