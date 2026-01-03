import SwiftUI

struct WheelSpecDraft: Equatable {
    var tireManufacturer: String = ""
    var tireModel: String = ""
    var tireWidthText: String = ""
    var tireProfileText: String = ""
    var diameterInches: Int = 0

    var rimManufacturer: String = ""
    var rimModel: String = ""
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
        _draft = State(initialValue: draft)
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
        let wOk = TextParsing.parseIntOptional(draft.tireWidthText) != nil
        let pOk = TextParsing.parseIntOptional(draft.tireProfileText) != nil
        let dOk = draft.diameterInches != 0
        return tireBrandOk && wOk && pOk && dOk
    }

    private func save() {
        guard isValid,
              let tireBrand = TextParsing.cleanOptional(draft.tireManufacturer),
              let w = TextParsing.parseIntOptional(draft.tireWidthText),
              let p = TextParsing.parseIntOptional(draft.tireProfileText)
        else { return }

        let rimBrand = TextParsing.cleanOptional(draft.rimManufacturer) ?? tireBrand

        let tireModel = TextParsing.cleanOptional(draft.tireModel)
        let rimModel = TextParsing.cleanOptional(draft.rimModel)

        let spec = WheelSpec(
            tireManufacturer: tireBrand,
            tireModel: tireModel,
            tireWidthMM: w,
            tireProfile: p,
            tireDiameterInches: draft.diameterInches,
            rimManufacturer: rimBrand,
            rimModel: rimModel,
            rimDiameterInches: draft.diameterInches
        )

        onSaved(spec)
        dismiss()
    }

    private func applyPrefill(from spec: WheelSpec) {
        draft.tireManufacturer = spec.tireManufacturer
        draft.tireModel = spec.tireModel ?? ""
        draft.tireWidthText = String(spec.tireWidthMM)
        draft.tireProfileText = String(spec.tireProfile)
        draft.diameterInches = spec.tireDiameterInches
        draft.rimManufacturer = spec.rimManufacturer
        draft.rimModel = spec.rimModel ?? ""
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

                    HStack {
                        TextField(String(localized: "wheelSet.field.tireWidth"), text: $draft.tireWidthText)
                            .keyboardType(.numberPad)
                        TextField(String(localized: "wheelSet.field.tireProfile"), text: $draft.tireProfileText)
                            .keyboardType(.numberPad)
                    }

                    Picker(String(localized: "wheelSet.field.tireDiameter"), selection: $draft.diameterInches) {
                        Text(String(localized: "vehicle.choice.notSet")).tag(0)
                        ForEach(WheelSpecsCatalog.rimDiameterChoices, id: \.self) { d in
                            Text("R\(d)").tag(d)
                        }
                    }
                }

                Section(String(localized: "wheelSet.section.rims")) {
                    TextField(String(localized: "wheelSet.field.rimManufacturer"), text: $draft.rimManufacturer)
                        .textInputAutocapitalization(.words)

                    TextField(String(localized: "wheelSet.field.rimModel"), text: $draft.rimModel)
                        .textInputAutocapitalization(.words)

                    LabeledContent(String(localized: "wheelSet.field.rimDiameter"), value: draft.diameterInches == 0 ? String(localized: "vehicle.choice.notSet") : "R\(draft.diameterInches)")
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
