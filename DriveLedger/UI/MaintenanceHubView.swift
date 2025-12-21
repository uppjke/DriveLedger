import SwiftUI
import SwiftData

struct MaintenanceHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var vehicle: Vehicle
    let showsCloseButton: Bool

    @State private var showAddReminder = false
    @State private var editingInterval: MaintenanceInterval?

    init(vehicle: Vehicle, showsCloseButton: Bool = true) {
        self.vehicle = vehicle
        self.showsCloseButton = showsCloseButton
    }

    private var currentOdometerKm: Int? {
        let fromEntries = vehicle.entries.compactMap { $0.odometerKm }.max()
        return fromEntries ?? vehicle.initialOdometerKm
    }

    private var intervals: [MaintenanceInterval] {
        vehicle.maintenanceIntervals.sorted {
            // Enabled first.
            if $0.isEnabled != $1.isEnabled { return $0.isEnabled && !$1.isEnabled }

            // Then by severity (if we can compute).
            let aStatus = $0.status(currentKm: currentOdometerKm)
            let bStatus = $1.status(currentKm: currentOdometerKm)
            let aSeverity = severity(aStatus)
            let bSeverity = severity(bStatus)
            if aSeverity != bSeverity { return aSeverity > bSeverity }

            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var addReminderFAB: some View {
        Button {
            showAddReminder = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .glassCircleBackground()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "maintenance.action.addInterval"))
        .accessibilityIdentifier("maintenance.add.fab")
    }

    var body: some View {
        NavigationStack {
            List {
                if intervals.isEmpty {
                    MaintenanceEmptyStateCard(
                        title: String(localized: "maintenance.empty.title"),
                        description: String(localized: "maintenance.empty.description")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(intervals) { interval in
                        MaintenanceReminderRow(interval: interval, currentKm: currentOdometerKm)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingInterval = interval
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingInterval = interval
                                } label: {
                                    Label(String(localized: "action.edit"), systemImage: "pencil")
                                }
                                .tint(Color(uiColor: .systemBlue).opacity(0.25))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    modelContext.delete(interval)
                                    do { try modelContext.save() } catch { print("Failed to delete interval: \(error)") }
                                } label: {
                                    Label(String(localized: "action.delete"), systemImage: "trash")
                                }
                                .tint(Color(uiColor: .systemRed).opacity(0.25))
                            }
                    }
                }
            }
            .navigationTitle(String(localized: "tab.maintenance"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    addReminderFAB
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.cancel")) { dismiss() }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddReminder) {
            AddMaintenanceReminderSheet(vehicle: vehicle, suggestedOdometerKm: currentOdometerKm)
        }
        .sheet(item: $editingInterval) { interval in
            EditMaintenanceReminderSheet(interval: interval)
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

private struct MaintenanceEmptyStateCard: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 44, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .padding(.vertical, 8)
    }
}

private struct MaintenanceReminderRow: View {
    @Bindable var interval: MaintenanceInterval
    let currentKm: Int?

    private var statusColor: Color {
        switch interval.status(currentKm: currentKm) {
        case .ok: return .green
        case .warning: return .orange
        case .overdue: return .red
        case .unknown: return .gray
        }
    }

    private var subtitle: String? {
        var parts: [String] = []

        if let last = interval.lastDoneDate {
            parts.append(last.formatted(date: .abbreviated, time: .omitted))
        }

        if let intervalKm = interval.intervalKm {
            parts.append(String.localizedStringWithFormat(String(localized: "maintenance.interval.km"), intervalKm))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var statusText: String? {
        guard interval.isEnabled else { return nil }
        guard let kmLeft = interval.kmUntilDue(currentKm: currentKm) else { return nil }
        if kmLeft < 0 {
            return String.localizedStringWithFormat(String(localized: "maintenance.status.overdue.km"), Int(-kmLeft))
        }
        return String.localizedStringWithFormat(String(localized: "maintenance.status.remaining.km"), Int(kmLeft))
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(interval.title)
                        .font(.headline)
                        .lineLimit(1)

                    if interval.notificationsEnabled {
                        Image(systemName: "bell")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let statusText {
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $interval.isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

private struct MaintenanceReminderTemplate: Identifiable, Hashable {
    let id: String
    let titleKey: String

    var title: String {
        String(localized: String.LocalizationValue(titleKey))
    }
}

private let maintenanceReminderTemplates: [MaintenanceReminderTemplate] = [
    .init(id: "engineOil", titleKey: "maintenance.template.engineOil"),
    .init(id: "transmissionOil", titleKey: "maintenance.template.transmissionOil"),
    .init(id: "oilFilter", titleKey: "maintenance.template.oilFilter"),
    .init(id: "airFilter", titleKey: "maintenance.template.airFilter"),
    .init(id: "cabinFilter", titleKey: "maintenance.template.cabinFilter"),
    .init(id: "sparkPlugs", titleKey: "maintenance.template.sparkPlugs"),
    .init(id: "brakePads", titleKey: "maintenance.template.brakePads"),
    .init(id: "brakeDiscs", titleKey: "maintenance.template.brakeDiscs"),
    .init(id: "brakeFluid", titleKey: "maintenance.template.brakeFluid"),
    .init(id: "coolant", titleKey: "maintenance.template.coolant"),
    .init(id: "timingBelt", titleKey: "maintenance.template.timingBelt"),
    .init(id: "tireRotation", titleKey: "maintenance.template.tireRotation"),
    .init(id: "wheelAlignment", titleKey: "maintenance.template.wheelAlignment"),
    .init(id: "battery", titleKey: "maintenance.template.battery"),
    .init(id: "inspection", titleKey: "maintenance.template.inspection")
]

private struct AddMaintenanceReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var vehicle: Vehicle
    let suggestedOdometerKm: Int?

    var body: some View {
        NavigationStack {
            List(maintenanceReminderTemplates) { template in
                NavigationLink(value: template) {
                    Text(template.title)
                }
            }
            .navigationTitle(String(localized: "maintenance.add.chooseType"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
            }
            .navigationDestination(for: MaintenanceReminderTemplate.self) { template in
                MaintenanceReminderEditor(
                    mode: .create(template: template),
                    vehicle: vehicle,
                    suggestedOdometerKm: suggestedOdometerKm,
                    onDone: {
                        dismiss()
                    }
                )
            }
        }
    }
}

private struct EditMaintenanceReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var interval: MaintenanceInterval

    var body: some View {
        NavigationStack {
            MaintenanceReminderEditor(
                mode: .edit(interval: interval),
                vehicle: interval.vehicle,
                suggestedOdometerKm: nil,
                onDone: nil
            )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.cancel")) { dismiss() }
                    }
                }
        }
    }
}

private struct MaintenanceReminderEditor: View {
    enum Mode {
        case create(template: MaintenanceReminderTemplate)
        case edit(interval: MaintenanceInterval)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode
    let vehicle: Vehicle?
    let suggestedOdometerKm: Int?
    let onDone: (() -> Void)?

    @State private var titleText: String = ""
    @State private var intervalKmText: String = ""
    @State private var lastDateKnown: Bool = false
    @State private var lastDoneDate: Date = Date()
    @State private var lastDoneOdometerText: String = ""
    @State private var notificationsEnabled: Bool = false
    @State private var isEnabled: Bool = true

    private var parsedIntervalKm: Int? {
        let v = TextParsing.parseIntOptional(intervalKmText)
        guard let v else { return nil }
        return v > 0 ? v : nil
    }

    private var parsedLastDoneOdometerKm: Int? {
        let t = lastDoneOdometerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        guard let v = Int(t) else { return nil }
        return v >= 0 ? v : nil
    }

    private var lastDoneOdometerIsInvalid: Bool {
        let t = lastDoneOdometerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        guard let v = Int(t) else { return true }
        return v < 0
    }

    private var canSave: Bool {
        let titleOK = !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let intervalOK = parsedIntervalKm != nil
        let lastOdoOK = !lastDateKnown || !lastDoneOdometerIsInvalid
        return titleOK && intervalOK && lastOdoOK
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "maintenance.field.title"), text: $titleText)

                TextField(String(localized: "maintenance.field.intervalKm"), text: $intervalKmText)
                    .keyboardType(.numberPad)
            }

            Section {
                Toggle(String(localized: "maintenance.field.setLastDoneDate"), isOn: $lastDateKnown)
                if lastDateKnown {
                    DatePicker(String(localized: "maintenance.field.lastDoneDate"), selection: $lastDoneDate, displayedComponents: [.date])

                    TextField(String(localized: "maintenance.field.lastDoneOdometer"), text: $lastDoneOdometerText)
                        .keyboardType(.numberPad)
                }
            }

            Section {
                Toggle(String(localized: "maintenance.field.notifications"), isOn: $notificationsEnabled)
            } footer: {
                Text(String(localized: "maintenance.field.notifications.footer"))
            }

            Section {
                Toggle(String(localized: "maintenance.field.active"), isOn: $isEnabled)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "action.save")) {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            populateInitialState()
        }
        .onChange(of: lastDateKnown) { _, newValue in
            guard newValue else {
                lastDoneOdometerText = ""
                return
            }
            guard lastDoneOdometerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if let suggestedOdometerKm {
                lastDoneOdometerText = String(suggestedOdometerKm)
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create:
            return String(localized: "maintenance.add.title")
        case .edit:
            return String(localized: "maintenance.edit.title")
        }
    }

    private func populateInitialState() {
        switch mode {
        case .create(let template):
            titleText = template.title
            intervalKmText = ""
            lastDateKnown = false
            lastDoneDate = Date()
            lastDoneOdometerText = ""
            notificationsEnabled = false
            isEnabled = true
        case .edit(let interval):
            titleText = interval.title
            intervalKmText = interval.intervalKm.map(String.init) ?? ""
            if let d = interval.lastDoneDate {
                lastDateKnown = true
                lastDoneDate = d
            } else {
                lastDateKnown = false
                lastDoneDate = Date()
            }

            if lastDateKnown, let km = interval.lastDoneOdometerKm {
                lastDoneOdometerText = String(km)
            } else {
                lastDoneOdometerText = ""
            }
            notificationsEnabled = interval.notificationsEnabled
            isEnabled = interval.isEnabled
        }
    }

    private func save() {
        guard let intervalKm = parsedIntervalKm else { return }
        let cleanedTitle = TextParsing.cleanRequired(titleText, fallback: String(localized: "maintenance.defaultTitle"))
        let resolvedLastDate: Date? = lastDateKnown ? lastDoneDate : nil
        let resolvedLastOdometer: Int? = lastDateKnown ? parsedLastDoneOdometerKm : nil

        switch mode {
        case .create:
            guard let vehicle else { return }
            let newInterval = MaintenanceInterval(
                title: cleanedTitle,
                intervalKm: intervalKm,
                intervalMonths: nil,
                lastDoneDate: resolvedLastDate,
                lastDoneOdometerKm: resolvedLastOdometer,
                notificationsEnabled: notificationsEnabled,
                notes: nil,
                isEnabled: isEnabled,
                vehicle: vehicle
            )
            vehicle.maintenanceIntervals.append(newInterval)
        case .edit(let interval):
            interval.title = cleanedTitle
            interval.intervalKm = intervalKm
            interval.lastDoneDate = resolvedLastDate
            interval.lastDoneOdometerKm = resolvedLastOdometer
            interval.notificationsEnabled = notificationsEnabled
            interval.isEnabled = isEnabled
        }

        do { try modelContext.save() } catch { print("Failed to save reminder: \(error)") }
        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }
}
