import SwiftUI
import SwiftData

struct WheelSetPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let vehicle: Vehicle
    @Binding var selection: String

    @State private var editingWheelSetID: UUID? = nil

    @State private var isWheelSpecEditorPresented: Bool = false
    @State private var wheelSpecDraft: WheelSpecDraft = WheelSpecDraft()
    @State private var wheelSpecEditIndex: Int? = nil

    @State private var newlyCreatedWheelSetID: UUID? = nil

    @State private var selectedWheelSpec: WheelSpec? = nil

    private let wheelCircleSize: CGFloat = 40
    private let wheelCircleSpacing: CGFloat = 10

    private var wheelSlotsWidth: CGFloat {
        wheelCircleSize * 4 + wheelCircleSpacing * 3
    }

    private var swipeActionTintOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.5
    }

    private var sortedWheelSets: [WheelSet] {
        vehicle.wheelSets.sorted { a, b in
            let an = a.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let bn = b.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameCmp = an.localizedCaseInsensitiveCompare(bn)
            if nameCmp != .orderedSame { return nameCmp == .orderedAscending }
            return a.id.uuidString < b.id.uuidString
        }
    }

    private var isEditing: Bool {
        editingWheelSetID != nil
    }

    private var editingWheelSet: WheelSet? {
        guard let id = editingWheelSetID else { return nil }
        return vehicle.wheelSets.first(where: { $0.id == id })
    }

    private func isSelected(_ ws: WheelSet) -> Bool {
        selection == ws.id.uuidString
    }

    private var editingWheelSpecs: [WheelSpec] {
        editingWheelSet?.wheelSpecs ?? []
    }

    private var wheelSpecPrefillOptions: [WheelSpec] {
        var seen = Set<String>()
        var result: [WheelSpec] = []
        for spec in editingWheelSpecs {
            if seen.insert(spec.dedupKey).inserted {
                result.append(spec)
            }
        }
        return result
    }

    private func draft(from spec: WheelSpec) -> WheelSpecDraft {
        WheelSpecDraft(
            tireManufacturer: spec.tireManufacturer,
            tireModel: spec.tireModel ?? "",
            tireSeasonRaw: spec.tireSeason?.rawValue ?? "",
            tireStudded: spec.tireStudded ?? false,
            tireWidthText: String(spec.tireWidthMM),
            tireProfileText: String(spec.tireProfile),
            tireDiameterInches: spec.tireDiameterInches,
            tireSpeedIndex: spec.tireSpeedIndex ?? "",
            tireLoadIndex: spec.tireLoadIndex ?? "",
            tireProductionYearText: spec.tireProductionYear.map(String.init) ?? "",
            rimManufacturer: spec.rimManufacturer,
            rimModel: spec.rimModel ?? "",
            rimTypeRaw: spec.rimType?.rawValue ?? "",
            rimDiameterInches: spec.rimDiameterInches,
            rimWidthInches: spec.rimWidthInches ?? 0,
            rimOffsetET: spec.rimOffsetET ?? 0,
            rimCenterBoreText: spec.rimCenterBoreMM.map { v in
                let isInt = abs(v.rounded() - v) < 0.000_001
                return isInt ? String(Int(v.rounded())) : String(format: "%.1f", v)
            } ?? "",
            rimBoltPattern: spec.rimBoltPattern ?? ""
        )
    }

    private func startEditingWheelSpec(at index: Int) {
        guard let ws = editingWheelSet else { return }
        guard index >= 0, index < ws.wheelSpecs.count else { return }

        wheelSpecDraft = draft(from: ws.wheelSpecs[index])
        wheelSpecEditIndex = index
        isWheelSpecEditorPresented = true
    }

    private func showWheelSpecEditor() {
        let last = editingWheelSpecs.last
        wheelSpecEditIndex = nil
        wheelSpecDraft = WheelSpecDraft(
            tireManufacturer: "",
            tireModel: "",
            tireSeasonRaw: last?.tireSeason?.rawValue ?? "",
            tireStudded: last?.tireStudded ?? false,
            tireWidthText: "",
            tireProfileText: "",
            tireDiameterInches: last?.tireDiameterInches ?? 0,
            tireSpeedIndex: "",
            tireLoadIndex: "",
            tireProductionYearText: "",
            rimManufacturer: "",
            rimModel: "",
            rimTypeRaw: last?.rimType?.rawValue ?? "",
            rimDiameterInches: last?.rimDiameterInches ?? (last?.tireDiameterInches ?? 0),
            rimWidthInches: last?.rimWidthInches ?? 0,
            rimOffsetET: last?.rimOffsetET ?? 0,
            rimCenterBoreText: last?.rimCenterBoreMM.map { v in
                let isInt = abs(v.rounded() - v) < 0.000_001
                return isInt ? String(Int(v.rounded())) : String(format: "%.1f", v)
            } ?? "",
            rimBoltPattern: last?.rimBoltPattern ?? ""
        )
        isWheelSpecEditorPresented = true
    }

    private func startAddingNewWheelSet() {
        guard !isEditing else { return }

        let ws = WheelSet(name: String(localized: "wheelSet.defaultName"), vehicle: vehicle)
        ws.wheelSpecs = []
        modelContext.insert(ws)
        vehicle.wheelSets.append(ws)
        vehicle.currentWheelSetID = ws.id
        selection = ws.id.uuidString
        editingWheelSetID = ws.id
        newlyCreatedWheelSetID = ws.id

        do { try modelContext.save() } catch { print("Failed to create wheel set: \(error)") }
    }

    private func startEditing(_ ws: WheelSet) {
        guard !isEditing else { return }
        selection = ws.id.uuidString
        editingWheelSetID = ws.id
    }

    private func saveEditing() {
        guard let ws = editingWheelSet else { return }

        let computedName = ws.autoName
        if !computedName.isEmpty {
            ws.name = computedName
        }

        if let tire = ws.representativeTireSpec() {
            ws.tireManufacturer = tire.tireManufacturer
            ws.tireModel = tire.tireModel
            ws.tireWidthMM = tire.tireWidthMM
            ws.tireProfile = tire.tireProfile
            ws.tireDiameterInches = tire.tireDiameterInches
            ws.tireSize = "\(tire.tireWidthMM)/\(tire.tireProfile) \(tire.diameterLabel)"

            ws.tireSeason = tire.tireSeason
            ws.tireStudded = tire.tireStudded
            ws.tireSpeedIndex = tire.tireSpeedIndex
        }

        if let rim = ws.representativeRimSpec() {
            ws.rimManufacturer = rim.rimManufacturer
            ws.rimModel = rim.rimModel
            ws.rimType = rim.rimType
            ws.rimDiameterInches = rim.rimDiameterInches
            ws.rimWidthInches = rim.rimWidthInches
            ws.rimOffsetET = rim.rimOffsetET
            ws.rimCenterBoreMM = rim.rimCenterBoreMM
            ws.rimBoltPattern = rim.rimBoltPattern

            ws.rimSpec = WheelSpecsCatalog.normalizeWheelSetRimSpec(
                rimType: rim.rimType,
                diameter: rim.rimDiameterInches,
                width: rim.rimWidthInches,
                offsetET: rim.rimOffsetET
            )
        }

        do { try modelContext.save() } catch { print("Failed to save wheel set: \(error)") }

        editingWheelSetID = nil
        newlyCreatedWheelSetID = nil
    }

    private func cancelEditing() {
        guard let ws = editingWheelSet else {
            editingWheelSetID = nil
            return
        }

        if newlyCreatedWheelSetID == ws.id, ws.wheelSpecs.isEmpty {
            deleteWheelSet(ws)
            newlyCreatedWheelSetID = nil
        } else {
            editingWheelSetID = nil
        }
    }

    private func saveWheelSpec(_ spec: WheelSpec) {
        guard let id = editingWheelSetID, let ws = vehicle.wheelSets.first(where: { $0.id == id }) else { return }
        var specs = ws.wheelSpecs

        if let editIndex = wheelSpecEditIndex {
            guard editIndex >= 0, editIndex < specs.count else { return }
            var updated = spec
            updated.id = specs[editIndex].id
            specs[editIndex] = updated
        } else {
            guard specs.count < 4 else { return }
            specs.append(spec)
        }

        ws.wheelSpecs = specs
        wheelSpecEditIndex = nil

        do { try modelContext.save() } catch { print("Failed to save wheel spec: \(error)") }
    }

    private func deleteWheelSet(_ ws: WheelSet) {
        withAnimation(.default) {
            if vehicle.currentWheelSetID == ws.id {
                vehicle.currentWheelSetID = nil
            }
            if selection == ws.id.uuidString {
                selection = ""
            }

            if editingWheelSetID == ws.id {
                editingWheelSetID = nil
            }

            if newlyCreatedWheelSetID == ws.id {
                newlyCreatedWheelSetID = nil
            }

            for e in vehicle.entries {
                if e.wheelSetID == ws.id {
                    e.wheelSetID = nil
                }
            }

            vehicle.wheelSets.removeAll { $0.id == ws.id }
        }

        modelContext.delete(ws)
        do { try modelContext.save() } catch { print("Failed to delete wheel set: \(error)") }
    }

    var body: some View {
        NavigationStack {
            List {
                GlassCardRow(isActive: selection.isEmpty) {
                    HStack {
                        Text(String(localized: "vehicle.choice.notSet"))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isEditing else { return }
                        selection = ""
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                ForEach(sortedWheelSets) { ws in
                    let isEditingThis = isEditing && editingWheelSetID == ws.id

                    GlassCardRow(isActive: isSelected(ws)) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(ws.autoName)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if isEditingThis {
                                    wheelSlotsRow(specs: ws.wheelSpecs, isEnabled: true, showsEditBadges: true)
                                } else {
                                    if !ws.wheelSpecs.isEmpty {
                                        wheelCirclesRow(specs: ws.wheelSpecs, isEnabled: !isEditing)
                                    } else if !ws.summary.isEmpty {
                                        Text(ws.summary)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .animation(.default, value: ws.wheelSpecs.count)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .onTapGesture {
                        guard !isEditing else { return }
                        selection = ws.id.uuidString
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if isEditingThis {
                            Button {
                                saveEditing()
                            } label: {
                                Label(String(localized: "action.save"), systemImage: "checkmark")
                            }
                            .disabled(ws.wheelSpecs.isEmpty)
                            .tint(Color(uiColor: .systemBlue).opacity(swipeActionTintOpacity))
                        } else if !isEditing {
                            Button {
                                startEditing(ws)
                            } label: {
                                Label(String(localized: "wheelSet.action.edit"), systemImage: "pencil")
                            }
                            .tint(Color(uiColor: .systemBlue).opacity(swipeActionTintOpacity))
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if isEditingThis {
                            Button {
                                deleteWheelSet(ws)
                            } label: {
                                Label(String(localized: "action.delete"), systemImage: "trash")
                            }
                            .tint(Color(uiColor: .systemRed).opacity(swipeActionTintOpacity))
                        } else if !isEditing {
                            Button {
                                deleteWheelSet(ws)
                            } label: {
                                Label(String(localized: "wheelSet.action.delete"), systemImage: "trash")
                            }
                            .tint(Color(uiColor: .systemRed).opacity(swipeActionTintOpacity))
                        }
                    }
                }
                .animation(.default, value: sortedWheelSets.map(\.id))
            }
            .listStyle(.plain)
            .listRowSpacing(10)
            .scrollContentBackground(.hidden)
            .navigationTitle(String(localized: "wheelSet.picker.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button(String(localized: "action.cancel")) {
                            cancelEditing()
                        }
                    } else {
                        Button(String(localized: "action.close")) { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.default) { startAddingNewWheelSet() }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(isEditing)
                }
            }
            .sheet(isPresented: $isWheelSpecEditorPresented) {
                WheelSpecEditorSheet(draft: wheelSpecDraft, prefillOptions: wheelSpecPrefillOptions) { spec in
                    saveWheelSpec(spec)
                }
            }
            .sheet(item: $selectedWheelSpec) { spec in
                WheelSpecDetailsSheet(spec: spec)
            }
        }
    }
}
extension WheelSetPickerSheet {
    private func wheelSlotsRow(specs: [WheelSpec], isEnabled: Bool, showsEditBadges: Bool) -> some View {
        HStack(spacing: wheelCircleSpacing) {
            ForEach(0..<4, id: \.self) { idx in
                if idx < specs.count {
                    wheelCircleButton(
                        spec: specs[idx],
                        isEnabled: isEnabled,
                        showsEditBadge: showsEditBadges,
                        onTap: showsEditBadges ? { startEditingWheelSpec(at: idx) } : nil
                    )
                } else if idx == specs.count {
                    Button {
                        showWheelSpecEditor()
                    } label: {
                        Circle()
                            .fill(.thinMaterial)
                            .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.caption.weight(.semibold))
                            )
                            .frame(width: wheelCircleSize, height: wheelCircleSize)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: wheelCircleSize, height: wheelCircleSize)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: wheelSlotsWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func wheelCirclesRow(specs: [WheelSpec], isEnabled: Bool) -> some View {
        HStack(spacing: wheelCircleSpacing) {
            ForEach(0..<4, id: \.self) { idx in
                if idx < min(specs.count, 4) {
                    wheelCircleButton(spec: specs[idx], isEnabled: isEnabled, showsEditBadge: false)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: wheelCircleSize, height: wheelCircleSize)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: wheelSlotsWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    private func wheelCircleButton(spec: WheelSpec, isEnabled: Bool, showsEditBadge: Bool, onTap: (() -> Void)? = nil) -> some View {
        Button {
            if let onTap {
                onTap()
            } else {
                selectedWheelSpec = spec
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))

                Text(spec.diameterLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .overlay(alignment: .topTrailing) {
                if showsEditBadge {
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                        .offset(x: 6, y: -6)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: wheelCircleSize, height: wheelCircleSize)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct WheelSpecDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let spec: WheelSpec

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "wheelSet.section.tires")) {
                    Text(spec.tireDisplay)
                }

                Section(String(localized: "wheelSet.section.rims")) {
                    Text(spec.rimDisplay)
                }
            }
            .navigationTitle(String(localized: "wheelSpec.editor.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.close")) { dismiss() }
                }
            }
        }
    }
}
