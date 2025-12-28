//
//  MaintenanceIntervalsList.swift
//  DriveLedger
//

import SwiftUI
import SwiftData
import Foundation

fileprivate struct MaintenanceRecommendation: Identifiable {
    var id: String { titleKey }
    let titleKey: String
    let intervalKm: Int?
    let intervalMonths: Int?

    var localizedTitle: String {
        String(localized: String.LocalizationValue(titleKey))
    }
}

fileprivate let defaultMaintenanceRecommendations: [MaintenanceRecommendation] = [
    MaintenanceRecommendation(titleKey: "maintenance.reco.engineOil", intervalKm: 10_000, intervalMonths: 12),
    MaintenanceRecommendation(titleKey: "maintenance.reco.oilFilter", intervalKm: 10_000, intervalMonths: 12),
    MaintenanceRecommendation(titleKey: "maintenance.reco.airFilter", intervalKm: 15_000, intervalMonths: 12),
    MaintenanceRecommendation(titleKey: "maintenance.reco.cabinFilter", intervalKm: 15_000, intervalMonths: 12),
    MaintenanceRecommendation(titleKey: "maintenance.reco.brakeFluid", intervalKm: nil, intervalMonths: 24),
    MaintenanceRecommendation(titleKey: "maintenance.reco.coolant", intervalKm: nil, intervalMonths: 60)
]

struct MaintenanceIntervalsList: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vehicle: Vehicle
    
    @State private var showAddInterval = false
    @State private var editingInterval: MaintenanceInterval?
    @State private var markingDoneInterval: MaintenanceInterval?

    @State private var showRecommendationsSheet = false
    @State private var historyInterval: MaintenanceInterval?
    
    private var intervals: [MaintenanceInterval] {
        vehicle.maintenanceIntervals.sorted {
            let aStatus = $0.status(currentKm: currentOdometerKm)
            let bStatus = $1.status(currentKm: currentOdometerKm)

            let aSeverity = severity(aStatus)
            let bSeverity = severity(bStatus)
            if aSeverity != bSeverity { return aSeverity > bSeverity }

            // Enabled first.
            if $0.isEnabled != $1.isEnabled { return $0.isEnabled && !$1.isEnabled }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
    
    private var currentOdometerKm: Int? {
        vehicle.entries
            .compactMap { $0.odometerKm }
            .max()
    }
    
    var body: some View {
        Section {
            if intervals.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ContentUnavailableView(
                        String(localized: "maintenance.empty.title"),
                        systemImage: "wrench.and.screwdriver",
                        description: Text(String(localized: "maintenance.empty.description"))
                    )

                    HStack {
                        Button {
                            showRecommendationsSheet = true
                        } label: {
                            Label(String(localized: "maintenance.action.addRecommended"), systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            showAddInterval = true
                        } label: {
                            Label(String(localized: "maintenance.action.addInterval"), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 8)
            } else {
                ForEach(intervals) { interval in
                    MaintenanceIntervalRow(interval: interval, currentKm: currentOdometerKm)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(interval)
                            } label: {
                                Label(String(localized: "action.delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingInterval = interval
                            } label: {
                                Label(String(localized: "action.edit"), systemImage: "pencil")
                            }

                            Button {
                                historyInterval = interval
                            } label: {
                                Label(String(localized: "maintenance.action.history"), systemImage: "clock")
                            }

                            Button {
                                markingDoneInterval = interval
                            } label: {
                                Label(String(localized: "maintenance.action.markDone"), systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                }
            }
        } header: {
            HStack {
                Text(String(localized: "maintenance.intervals.header"))
                Spacer()
                Button {
                    showRecommendationsSheet = true
                } label: {
                    Image(systemName: "sparkles")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "maintenance.action.addRecommended"))
                Button {
                    showAddInterval = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "maintenance.action.addInterval"))
            }
        }
        .sheet(isPresented: $showAddInterval) {
            AddMaintenanceIntervalSheet(vehicle: vehicle, suggestedOdometerKm: currentOdometerKm)
        }
        .sheet(item: $editingInterval) { interval in
            EditMaintenanceIntervalSheet(interval: interval)
        }
        .sheet(item: $markingDoneInterval) { interval in
            MarkMaintenanceDoneSheet(interval: interval, vehicle: vehicle, suggestedOdometerKm: currentOdometerKm)
        }
        .sheet(isPresented: $showRecommendationsSheet) {
            RecommendedIntervalsSheet(vehicle: vehicle, suggestedOdometerKm: currentOdometerKm)
        }
        .sheet(item: $historyInterval) { interval in
            MaintenanceIntervalHistorySheet(interval: interval, vehicle: vehicle)
        }
    }

    private func severity(_ status: MaintenanceInterval.Status) -> Int {
        switch status {
        case .overdue:
            return 3
        case .warning:
            return 2
        case .ok:
            return 1
        case .unknown:
            return 0
        }
    }

}

struct MaintenanceIntervalRow: View {
    let interval: MaintenanceInterval
    let currentKm: Int?
    
    private var statusColor: Color {
        switch interval.status(currentKm: currentKm) {
        case .ok: return .green
        case .warning: return .orange
        case .overdue: return .red
        case .unknown: return .gray
        }
    }
    
    private var statusText: String {
        var parts: [String] = []

        if let kmLeft = interval.kmUntilDue(currentKm: currentKm) {
            if kmLeft < 0 {
                parts.append(
                    String.localizedStringWithFormat(
                        String(localized: "maintenance.status.overdue.km"),
                        Int(-kmLeft)
                    )
                )
            } else {
                parts.append(
                    String.localizedStringWithFormat(
                        String(localized: "maintenance.status.remaining.km"),
                        Int(kmLeft)
                    )
                )
            }
        }

        if let daysLeft = interval.daysUntilDue() {
            if daysLeft < 0 {
                parts.append(
                    String.localizedStringWithFormat(
                        String(localized: "maintenance.status.overdue.days"),
                        Int(-daysLeft)
                    )
                )
            } else {
                parts.append(
                    String.localizedStringWithFormat(
                        String(localized: "maintenance.status.remaining.days"),
                        Int(daysLeft)
                    )
                )
            }
        }

        if parts.isEmpty {
            return String(localized: "maintenance.status.notConfigured")
        }

        return parts.joined(separator: " • ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(statusColor)
                Text(interval.title)
                    .font(.headline)
                Spacer()
                if !interval.isEnabled {
                    Text(String(localized: "maintenance.row.disabled"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if interval.isEnabled {
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)
                
                HStack(spacing: 12) {
                    if let intervalKm = interval.intervalKm {
                        Label(
                            String.localizedStringWithFormat(
                                String(localized: "maintenance.interval.km"),
                                intervalKm
                            ),
                            systemImage: "road.lanes"
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let intervalMonths = interval.intervalMonths {
                        Label(
                            String.localizedStringWithFormat(
                                String(localized: "maintenance.interval.months"),
                                intervalMonths
                            ),
                            systemImage: "calendar"
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let lastDate = interval.lastDoneDate {
                    Text(String.localizedStringWithFormat(
                        String(localized: "maintenance.lastDone.date"),
                        lastDate.formatted(date: .abbreviated, time: .omitted)
                    ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastKm = interval.lastDoneOdometerKm {
                    Text(String.localizedStringWithFormat(
                        String(localized: "maintenance.lastDone.odometer"),
                        lastKm
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            
            if let notes = interval.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .opacity(interval.isEnabled ? 1.0 : 0.6)
    }
}

struct AddMaintenanceIntervalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vehicle: Vehicle
    let suggestedOdometerKm: Int?
    
    @State private var title = ""
    @State private var intervalKm = ""
    @State private var intervalMonths = ""
    @State private var notes = ""

    @State private var startFromNow = true
    @State private var lastDoneDate = Date()
    @State private var lastDoneOdometerKm = ""

    @FocusState private var focusedField: Field?
    private enum Field {
        case title
        case intervalKm
        case intervalMonths
        case lastDoneOdo
        case notes
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "maintenance.section.main")) {
                    TextField(String(localized: "maintenance.field.title"), text: $title)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .title)
                    TextField(String(localized: "maintenance.field.intervalKm"), text: $intervalKm)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .intervalKm)
                    TextField(String(localized: "maintenance.field.intervalMonths"), text: $intervalMonths)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .intervalMonths)
                }

                Section(String(localized: "maintenance.section.baseline")) {
                    Toggle(String(localized: "maintenance.field.startFromNow"), isOn: $startFromNow)

                    if !startFromNow {
                        DatePicker(String(localized: "maintenance.field.lastDoneDate"), selection: $lastDoneDate, displayedComponents: [.date])
                        TextField(String(localized: "maintenance.field.lastDoneOdometer"), text: $lastDoneOdometerKm)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .lastDoneOdo)
                    }
                }
                
                Section(String(localized: "maintenance.section.notes")) {
                    TextField(String(localized: "maintenance.field.notes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle(String(localized: "maintenance.sheet.new.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.create")) {
                        let parsedKm = Int(intervalKm)
                        let parsedMonths = Int(intervalMonths)

                        let baselineDate: Date? = startFromNow ? Date() : lastDoneDate
                        let baselineOdo: Int? = startFromNow ? suggestedOdometerKm : Int(lastDoneOdometerKm)

                        let interval = MaintenanceInterval(
                            title: title.isEmpty ? String(localized: "maintenance.defaultTitle") : title,
                            intervalKm: parsedKm,
                            intervalMonths: parsedMonths,
                            lastDoneDate: baselineDate,
                            lastDoneOdometerKm: baselineOdo,
                            notes: notes.isEmpty ? nil : notes,
                            vehicle: vehicle
                        )
                        modelContext.insert(interval)
                        dismiss()
                    }
                    .disabled(intervalKm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && intervalMonths.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "action.ok")) { focusedField = nil }
                }
            }
            .onAppear {
                lastDoneOdometerKm = suggestedOdometerKm.map(String.init) ?? ""
            }
        }
    }
}

struct EditMaintenanceIntervalSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var interval: MaintenanceInterval
    
    @State private var title = ""
    @State private var intervalKm = ""
    @State private var intervalMonths = ""
    @State private var notes = ""
    @State private var isEnabled = true

    @State private var lastDoneDate = Date()
    @State private var hasLastDoneDate = false
    @State private var lastDoneOdometerKm = ""
    @State private var hasLastDoneOdometer = false

    @FocusState private var focusedField: Field?
    private enum Field {
        case title
        case intervalKm
        case intervalMonths
        case lastDoneOdo
        case notes
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "maintenance.section.main")) {
                    TextField(String(localized: "maintenance.field.title"), text: $title)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .title)
                    TextField(String(localized: "maintenance.field.intervalKm"), text: $intervalKm)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .intervalKm)
                    TextField(String(localized: "maintenance.field.intervalMonths"), text: $intervalMonths)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .intervalMonths)
                    Toggle(String(localized: "maintenance.field.active"), isOn: $isEnabled)
                }

                Section(String(localized: "maintenance.section.lastDone")) {
                    Toggle(String(localized: "maintenance.field.setLastDoneDate"), isOn: $hasLastDoneDate)
                    if hasLastDoneDate {
                        DatePicker(String(localized: "maintenance.field.lastDoneDate"), selection: $lastDoneDate, displayedComponents: [.date])
                    }

                    Toggle(String(localized: "maintenance.field.setLastDoneOdometer"), isOn: $hasLastDoneOdometer)
                    if hasLastDoneOdometer {
                        TextField(String(localized: "maintenance.field.lastDoneOdometer"), text: $lastDoneOdometerKm)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .lastDoneOdo)
                    }
                }
                
                Section(String(localized: "maintenance.section.notes")) {
                    TextField(String(localized: "maintenance.field.notes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle(String(localized: "maintenance.sheet.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        interval.title = title
                        interval.intervalKm = Int(intervalKm)
                        interval.intervalMonths = Int(intervalMonths)
                        interval.notes = notes.isEmpty ? nil : notes
                        interval.isEnabled = isEnabled

                        interval.lastDoneDate = hasLastDoneDate ? lastDoneDate : nil
                        interval.lastDoneOdometerKm = hasLastDoneOdometer ? Int(lastDoneOdometerKm) : nil
                        dismiss()
                    }
                    .disabled(intervalKm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && intervalMonths.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "action.ok")) { focusedField = nil }
                }
            }
            .onAppear {
                title = interval.title
                intervalKm = interval.intervalKm.map(String.init) ?? ""
                intervalMonths = interval.intervalMonths.map(String.init) ?? ""
                notes = interval.notes ?? ""
                isEnabled = interval.isEnabled

                if let d = interval.lastDoneDate {
                    hasLastDoneDate = true
                    lastDoneDate = d
                } else {
                    hasLastDoneDate = false
                    lastDoneDate = Date()
                }

                if let km = interval.lastDoneOdometerKm {
                    hasLastDoneOdometer = true
                    lastDoneOdometerKm = String(km)
                } else {
                    hasLastDoneOdometer = false
                    lastDoneOdometerKm = ""
                }
            }
        }
    }
}

struct MarkMaintenanceDoneSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var interval: MaintenanceInterval
    let vehicle: Vehicle
    let suggestedOdometerKm: Int?

    @State private var doneDate = Date()
    @State private var odometerKmText = ""
    @State private var costText = ""
    @State private var notesText = ""

    @FocusState private var focusedField: Field?
    private enum Field {
        case odometer
        case cost
        case notes
    }

    private func cleanOptional(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "maintenance.sheet.markDone.section")) {
                    DatePicker(String(localized: "maintenance.sheet.markDone.date"), selection: $doneDate, displayedComponents: [.date])
                    TextField(String(localized: "maintenance.sheet.markDone.odometer"), text: $odometerKmText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .odometer)
                    TextField(String(localized: "maintenance.sheet.markDone.cost"), text: $costText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .cost)
                    TextField(String(localized: "maintenance.sheet.markDone.notes"), text: $notesText, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle(String(localized: "maintenance.sheet.markDone.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "maintenance.sheet.markDone.confirm")) {
                        let odo = TextParsing.parseIntOptional(odometerKmText) ?? suggestedOdometerKm
                        interval.lastDoneDate = doneDate
                        interval.lastDoneOdometerKm = odo

                        let entry = LogEntry(kind: .service, vehicle: vehicle)
                        entry.setServiceChecklistItems([interval.title])
                        entry.serviceTitle = TextParsing.buildServiceTitleFromChecklist([interval.title])
                        entry.setLinkedMaintenanceIntervals([interval.id])
                        entry.date = doneDate
                        entry.odometerKm = odo
                        entry.totalCost = TextParsing.parseDouble(costText)
                        entry.notes = cleanOptional(notesText) ?? String(localized: "maintenance.entry.plannedNote")
                        modelContext.insert(entry)

                        dismiss()
                    }
                    .disabled((TextParsing.parseIntOptional(odometerKmText) ?? suggestedOdometerKm) == nil)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "action.ok")) { focusedField = nil }
                }
            }
            .onAppear {
                odometerKmText = suggestedOdometerKm.map(String.init) ?? ""
            }
        }
    }
}

private struct RecommendedIntervalsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle
    let suggestedOdometerKm: Int?

    @State private var selectedKeys: Set<String> = []

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var existingTitles: Set<String> {
        Set(vehicle.maintenanceIntervals.map { normalize($0.title) })
    }

    private func isAlreadyAdded(_ reco: MaintenanceRecommendation) -> Bool {
        existingTitles.contains(normalize(reco.localizedTitle))
    }

    private func binding(for reco: MaintenanceRecommendation) -> Binding<Bool> {
        Binding(
            get: { selectedKeys.contains(reco.titleKey) },
            set: { isOn in
                if isOn {
                    selectedKeys.insert(reco.titleKey)
                } else {
                    selectedKeys.remove(reco.titleKey)
                }
            }
        )
    }

    private func addSelected() {
        let now = Date()

        for reco in defaultMaintenanceRecommendations {
            guard selectedKeys.contains(reco.titleKey) else { continue }
            guard !isAlreadyAdded(reco) else { continue }

            let interval = MaintenanceInterval(
                title: reco.localizedTitle,
                intervalKm: reco.intervalKm,
                intervalMonths: reco.intervalMonths,
                lastDoneDate: now,
                lastDoneOdometerKm: suggestedOdometerKm,
                notes: nil,
                isEnabled: true,
                vehicle: vehicle
            )
            modelContext.insert(interval)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(defaultMaintenanceRecommendations) { reco in
                        Toggle(isOn: binding(for: reco)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reco.localizedTitle)

                                HStack(spacing: 12) {
                                    if let km = reco.intervalKm {
                                        Label(
                                            String.localizedStringWithFormat(String(localized: "maintenance.interval.km"), km),
                                            systemImage: "road.lanes"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    if let months = reco.intervalMonths {
                                        Label(
                                            String.localizedStringWithFormat(String(localized: "maintenance.interval.months"), months),
                                            systemImage: "calendar"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }

                                if isAlreadyAdded(reco) {
                                    Text(String(localized: "maintenance.reco.alreadyAdded"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(isAlreadyAdded(reco))
                    }
                }
            }
            .navigationTitle(String(localized: "maintenance.reco.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.add")) {
                        addSelected()
                        dismiss()
                    }
                    .disabled(selectedKeys.isEmpty)
                }
            }
            .onAppear {
                selectedKeys = Set(defaultMaintenanceRecommendations
                    .filter { !isAlreadyAdded($0) }
                    .map { $0.titleKey }
                )
            }
        }
    }
}

private struct MaintenanceIntervalHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let interval: MaintenanceInterval
    let vehicle: Vehicle

    @State private var editingEntry: LogEntry?

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var historyEntries: [LogEntry] {
        vehicle.entries
            .filter { entry in
                guard entry.kind == .service else { return false }
                if entry.linkedMaintenanceIntervalIDs.contains(interval.id) { return true }

                // Backward compatibility for older entries created before explicit linking.
                if entry.linkedMaintenanceIntervalIDs.isEmpty,
                   let title = entry.serviceTitle,
                   normalize(title) == normalize(interval.title) {
                    return true
                }

                return false
            }
            .sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                let a = $0.odometerKm ?? Int.min
                let b = $1.odometerKm ?? Int.min
                if a != b { return a > b }
                return $0.id.uuidString > $1.id.uuidString
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if historyEntries.isEmpty {
                    ContentUnavailableView(
                        String(localized: "maintenance.history.empty.title"),
                        systemImage: "clock",
                        description: Text(String(localized: "maintenance.history.empty.description"))
                    )
                } else {
                    List {
                        ForEach(historyEntries) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(entry.serviceTitle ?? interval.title)
                                            .font(.headline)
                                        Spacer()
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack(spacing: 12) {
                                        if let km = entry.odometerKm {
                                            Label("\(km)", systemImage: "speedometer")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let cost = entry.totalCost {
                                            Label(cost.formatted(.number.precision(.fractionLength(2))), systemImage: "tag")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if let notes = entry.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(interval.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.close")) { dismiss() }
                }
            }
            .sheet(item: $editingEntry) { entry in
                EditEntrySheet(entry: entry, existingEntries: vehicle.entries)
            }
        }
    }
}
