import SwiftUI
import SwiftData

struct MaintenanceHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var vehicle: Vehicle
    let showsCloseButton: Bool

    @State private var showAddReminder = false
    @State private var editingInterval: MaintenanceInterval?
    @State private var markingDoneInterval: MaintenanceInterval?

    init(vehicle: Vehicle, showsCloseButton: Bool = true) {
        self.vehicle = vehicle
        self.showsCloseButton = showsCloseButton
    }

    private var swipeActionTintOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.5
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
                                .tint(Color(uiColor: .systemBlue).opacity(swipeActionTintOpacity))

                                Button {
                                    markingDoneInterval = interval
                                } label: {
                                    Label(String(localized: "serviceBook.action.markDone"), systemImage: "checkmark.circle")
                                }
                                .tint(Color(uiColor: .systemGreen).opacity(swipeActionTintOpacity))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task { await MaintenanceNotifications.remove(intervalID: interval.id) }
                                    modelContext.delete(interval)
                                    do { try modelContext.save() } catch { print("Failed to delete interval: \(error)") }
                                } label: {
                                    Label(String(localized: "action.delete"), systemImage: "trash")
                                }
                                .tint(Color(uiColor: .systemRed).opacity(swipeActionTintOpacity))
                            }
                    }
                }
            }
            .navigationTitle(String(localized: "tab.maintenance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button {
                        showAddReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "maintenance.action.addInterval"))
                    .accessibilityIdentifier("maintenance.add.fab")
                }

                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.cancel")) { dismiss() }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ServiceBookHistoryView(vehicle: vehicle)
                    } label: {
                        Image(systemName: "clock")
                            .symbolRenderingMode(.hierarchical)
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(String(localized: "serviceBook.history.title"))
                }
            }
        }
        .sheet(isPresented: $showAddReminder) {
            AddMaintenanceReminderSheet(vehicle: vehicle, suggestedOdometerKm: currentOdometerKm)
        }
        .sheet(item: $editingInterval) { interval in
            EditMaintenanceReminderSheet(interval: interval)
        }
        .sheet(item: $markingDoneInterval) { interval in
            MarkServiceBookDoneSheet(interval: interval, vehicle: vehicle, suggestedOdometerKm: currentOdometerKm)
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

private struct MarkServiceBookDoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var interval: MaintenanceInterval
    @Bindable var vehicle: Vehicle
    let suggestedOdometerKm: Int?

    @State private var date: Date = Date()
    @State private var odometerText: String = ""
    @State private var performedBy: ServiceBookPerformedBy = .service
    @State private var serviceName: String = ""
    @State private var notes: String = ""

    // Adaptive oil fields (engine oil only)
    private let oilViscosityOptions: [String] = [
        "0W-20", "0W-30", "5W-30", "5W-40", "10W-40", String(localized: "serviceBook.oil.viscosity.custom")
    ]
    @State private var oilBrand: String = ""
    @State private var oilViscosity: String = "5W-30"
    @State private var oilViscosityCustom: String = ""
    @State private var oilSpec: String = ""

    private var isEngineOilTemplate: Bool {
        interval.templateID == "engineOil"
    }

    private var parsedOdometer: Int? {
        TextParsing.parseIntOptional(odometerText)
    }

    private var odometerIsInvalid: Bool {
        let t = odometerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        guard let v = Int(t) else { return true }
        return v < 0
    }

    private var odometerRequired: Bool {
        interval.intervalKm != nil
    }

    private var canSave: Bool {
        if odometerRequired {
            return parsedOdometer != nil && !odometerIsInvalid
        }
        return !odometerIsInvalid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(String(localized: "serviceBook.field.date"), selection: $date, displayedComponents: [.date])

                    TextField(String(localized: "serviceBook.field.odometer"), text: $odometerText)
                        .keyboardType(.numberPad)
                }

                Section {
                    Picker(String(localized: "serviceBook.field.performedBy"), selection: $performedBy) {
                        ForEach(ServiceBookPerformedBy.allCases) { v in
                            Text(v.title).tag(v)
                        }
                    }
                    .pickerStyle(.segmented)

                    if performedBy == .service {
                        TextField(String(localized: "serviceBook.field.serviceName"), text: $serviceName)
                    }
                }

                if isEngineOilTemplate {
                    Section(String(localized: "serviceBook.section.oil")) {
                        TextField(String(localized: "serviceBook.oil.brand"), text: $oilBrand)

                        Picker(String(localized: "serviceBook.oil.viscosity"), selection: $oilViscosity) {
                            ForEach(oilViscosityOptions, id: \.self) { v in
                                Text(v).tag(v)
                            }
                        }

                        if oilViscosity == String(localized: "serviceBook.oil.viscosity.custom") {
                            TextField(String(localized: "serviceBook.oil.viscosity"), text: $oilViscosityCustom)
                        }

                        TextField(String(localized: "serviceBook.oil.spec"), text: $oilSpec)
                    }
                }

                Section {
                    TextField(String(localized: "serviceBook.field.notes"), text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(String(localized: "serviceBook.action.markDone"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if odometerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggestedOdometerKm {
                odometerText = String(suggestedOdometerKm)
            }
        }
    }

    private func save() {
        let odo = parsedOdometer
        if odometerRequired, odo == nil { return }

        let cleanedServiceName = TextParsing.cleanOptional(serviceName)
        let cleanedNotes = TextParsing.cleanOptional(notes)

        let resolvedViscosity: String? = {
            guard isEngineOilTemplate else { return nil }
            if oilViscosity == String(localized: "serviceBook.oil.viscosity.custom") {
                return TextParsing.cleanOptional(oilViscosityCustom)
            }
            return oilViscosity
        }()

        let entry = ServiceBookEntry(
            intervalID: interval.id,
            title: interval.title,
            date: date,
            odometerKm: odo,
            performedBy: performedBy,
            serviceName: cleanedServiceName,
            oilBrand: isEngineOilTemplate ? TextParsing.cleanOptional(oilBrand) : nil,
            oilViscosity: resolvedViscosity,
            oilSpec: isEngineOilTemplate ? TextParsing.cleanOptional(oilSpec) : nil,
            notes: cleanedNotes,
            vehicle: vehicle
        )

        modelContext.insert(entry)

        vehicle.serviceBookEntries.append(entry)

        interval.lastDoneDate = date
        if let odo { interval.lastDoneOdometerKm = odo }

        do { try modelContext.save() } catch { print("Failed to save service book entry: \(error)") }

        Task {
            await MaintenanceNotifications.sync(
                intervalID: interval.id,
                title: interval.title,
                vehicleName: vehicle.name,
                dueDate: interval.nextDueDate(),
                nextDueKm: interval.nextDueKm(currentKm: odo),
                currentKm: odo,
                notificationsEnabled: interval.notificationsEnabled,
                notificationsByDateEnabled: interval.notificationsByDateEnabled,
                notificationsByMileageEnabled: interval.notificationsByMileageEnabled,
                leadDays: interval.notificationLeadDays,
                leadKm: interval.notificationLeadKm,
                timeMinutes: interval.notificationTimeMinutes,
                repeatRule: interval.notificationRepeat,
                isEnabled: interval.isEnabled
            )
        }
        dismiss()
    }
}

private struct ServiceBookHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var vehicle: Vehicle

    private var swipeActionTintOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.5
    }

    private var entries: [ServiceBookEntry] {
        vehicle.serviceBookEntries.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            let a = $0.odometerKm ?? Int.min
            let b = $1.odometerKm ?? Int.min
            if a != b { return a > b }
            return $0.id.uuidString > $1.id.uuidString
        }
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private func relatedAttachments(for e: ServiceBookEntry) -> [Attachment] {
        let relevantEntries = vehicle.entries.filter { le in
            guard le.kind == .service || le.kind == .tireService else { return false }
            guard le.linkedMaintenanceIntervalIDs.contains(e.intervalID) else { return false }
            if isSameDay(le.date, e.date) { return true }
            if let a = le.odometerKm, let b = e.odometerKm, a == b { return true }
            return false
        }

        return relevantEntries
            .flatMap { $0.attachments }
            .filter { att in
                if att.appliesToAllMaintenanceIntervals { return true }
                return att.scopedMaintenanceIntervalIDs.contains(e.intervalID)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    String(localized: "serviceBook.history.empty.title"),
                    systemImage: "clock",
                    description: Text(String(localized: "serviceBook.history.empty.description"))
                )
            } else {
                ForEach(entries) { e in
                    let attachments = relatedAttachments(for: e)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(e.title)
                            .font(.headline)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(e.date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                            if let odo = e.odometerKm {
                                Text("•").foregroundStyle(.secondary)
                                Text("\(odo) км")
                            }
                            Text("•").foregroundStyle(.secondary)
                            Text(e.performedBy.title)
                            if let service = e.serviceName, !service.isEmpty {
                                Text("•").foregroundStyle(.secondary)
                                Text(service)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if let brand = e.oilBrand, let visc = e.oilViscosity {
                            let spec = e.oilSpec
                            Text([
                                String(localized: "serviceBook.section.oil"),
                                brand,
                                visc,
                                spec
                            ]
                            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .joined(separator: " • "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if let notes = e.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if !attachments.isEmpty {
                            HStack(spacing: 8) {
                                Label("\(attachments.count)", systemImage: "paperclip")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(attachments) { att in
                                if let url = try? AttachmentsStore.fileURL(relativePath: att.relativePath) {
                                    ShareLink(item: url) {
                                        Text(att.originalFileName)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                } else {
                                    Text(att.originalFileName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            modelContext.delete(e)
                            do { try modelContext.save() } catch { print("Failed to delete service book entry: \(error)") }
                        } label: {
                            Label(String(localized: "action.delete"), systemImage: "trash")
                        }
                        .tint(Color(uiColor: .systemRed).opacity(swipeActionTintOpacity))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "serviceBook.history.title"))
        .navigationBarTitleDisplayMode(.inline)
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

        if let intervalMonths = interval.intervalMonths {
            parts.append(String.localizedStringWithFormat(String(localized: "maintenance.interval.months"), intervalMonths))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var statusText: String? {
        guard interval.isEnabled else { return nil }
        var parts: [String] = []

        if let kmLeft = interval.kmUntilDue(currentKm: currentKm) {
            if kmLeft < 0 {
                parts.append(String.localizedStringWithFormat(String(localized: "maintenance.status.overdue.km"), Int(-kmLeft)))
            } else {
                parts.append(String.localizedStringWithFormat(String(localized: "maintenance.status.remaining.km"), Int(kmLeft)))
            }
        }

        if let daysLeft = interval.daysUntilDue() {
            if daysLeft < 0 {
                parts.append(String.localizedStringWithFormat(String(localized: "maintenance.status.overdue.days"), Int(-daysLeft)))
            } else {
                parts.append(String.localizedStringWithFormat(String(localized: "maintenance.status.remaining.days"), Int(daysLeft)))
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
        .onChange(of: interval.isEnabled) { _, _ in
            Task {
                await MaintenanceNotifications.sync(
                    intervalID: interval.id,
                    title: interval.title,
                    vehicleName: interval.vehicle?.name,
                    dueDate: interval.nextDueDate(),
                    nextDueKm: interval.nextDueKm(currentKm: currentKm),
                    currentKm: currentKm,
                    notificationsEnabled: interval.notificationsEnabled,
                    notificationsByDateEnabled: interval.notificationsByDateEnabled,
                    notificationsByMileageEnabled: interval.notificationsByMileageEnabled,
                    leadDays: interval.notificationLeadDays,
                    leadKm: interval.notificationLeadKm,
                    timeMinutes: interval.notificationTimeMinutes,
                    repeatRule: interval.notificationRepeat,
                    isEnabled: interval.isEnabled
                )
            }
        }
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
    @State private var intervalMonthsText: String = ""
    @State private var lastDateKnown: Bool = false
    @State private var lastDoneDate: Date = Date()
    @State private var lastDoneOdometerText: String = ""
    @State private var notificationsEnabled: Bool = false
    @State private var notificationsByDateEnabled: Bool = true
    @State private var notificationsByMileageEnabled: Bool = true
    @State private var notificationLeadDays: Int = 30
    @State private var notificationLeadKmText: String = ""
    @State private var notificationTime: Date = Date()
    @State private var notificationRepeat: MaintenanceNotificationRepeat = .none
    @State private var isEnabled: Bool = true

    private var parsedLeadKm: Int? {
        let t = notificationLeadKmText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        guard let v = Int(t) else { return nil }
        return v >= 0 ? v : nil
    }

    private func minutesFromMidnight(for date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let clamped = min(max(0, minutes), 24 * 60 - 1)
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = clamped / 60
        comps.minute = clamped % 60
        return Calendar.current.date(from: comps) ?? Date()
    }

    private var parsedIntervalKm: Int? {
        let v = TextParsing.parseIntOptional(intervalKmText)
        guard let v else { return nil }
        return v > 0 ? v : nil
    }

    private var parsedIntervalMonths: Int? {
        let v = TextParsing.parseIntOptional(intervalMonthsText)
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
        let intervalOK = (parsedIntervalKm != nil) || (parsedIntervalMonths != nil)
        let lastOdoOK = !lastDateKnown || !lastDoneOdometerIsInvalid
        return titleOK && intervalOK && lastOdoOK
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "maintenance.field.title"), text: $titleText)

                TextField(String(localized: "maintenance.field.intervalKm"), text: $intervalKmText)
                    .keyboardType(.numberPad)

                TextField(String(localized: "maintenance.field.intervalMonths"), text: $intervalMonthsText)
                    .keyboardType(.numberPad)
            } footer: {
                Text(String(localized: "serviceBook.interval.footer"))
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
                if notificationsEnabled {
                    Toggle(String(localized: "maintenance.notifications.byDate"), isOn: $notificationsByDateEnabled)
                    Stepper(
                        value: $notificationLeadDays,
                        in: 0...180,
                        step: 1
                    ) {
                        Text(String(format: String(localized: "maintenance.notifications.leadDays"), notificationLeadDays))
                    }
                    .disabled(!notificationsByDateEnabled)

                    DatePicker(
                        String(localized: "maintenance.notifications.time"),
                        selection: $notificationTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .disabled(!notificationsByDateEnabled && !notificationsByMileageEnabled)

                    Toggle(String(localized: "maintenance.notifications.byMileage"), isOn: $notificationsByMileageEnabled)
                    TextField(String(localized: "maintenance.notifications.leadKm"), text: $notificationLeadKmText)
                        .keyboardType(.numberPad)
                        .disabled(!notificationsByMileageEnabled)

                    Picker(String(localized: "maintenance.notifications.repeat"), selection: $notificationRepeat) {
                        ForEach(MaintenanceNotificationRepeat.allCases) { r in
                            Text(r.title).tag(r)
                        }
                    }
                }
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
            intervalMonthsText = ""
            lastDateKnown = false
            lastDoneDate = Date()
            lastDoneOdometerText = ""
            notificationsEnabled = false
            notificationsByDateEnabled = true
            notificationsByMileageEnabled = true
            notificationLeadDays = 30
            notificationLeadKmText = ""
            notificationTime = dateFromMinutes(9 * 60)
            notificationRepeat = .none
            isEnabled = true
        case .edit(let interval):
            titleText = interval.title
            intervalKmText = interval.intervalKm.map(String.init) ?? ""
            intervalMonthsText = interval.intervalMonths.map(String.init) ?? ""
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
            notificationsByDateEnabled = interval.notificationsByDateEnabled
            notificationsByMileageEnabled = interval.notificationsByMileageEnabled
            notificationLeadDays = interval.notificationLeadDays
            notificationLeadKmText = interval.notificationLeadKm.map(String.init) ?? ""
            notificationTime = dateFromMinutes(interval.notificationTimeMinutes)
            notificationRepeat = interval.notificationRepeat
            isEnabled = interval.isEnabled
        }
    }

    private func save() {
        let resolvedIntervalKm: Int? = parsedIntervalKm
        let resolvedIntervalMonths: Int? = parsedIntervalMonths
        guard resolvedIntervalKm != nil || resolvedIntervalMonths != nil else { return }
        let cleanedTitle = TextParsing.cleanRequired(titleText, fallback: String(localized: "maintenance.defaultTitle"))
        let resolvedLastDate: Date? = lastDateKnown ? lastDoneDate : nil
        let resolvedLastOdometer: Int? = lastDateKnown ? parsedLastDoneOdometerKm : nil
        let resolvedLeadDays = max(0, notificationLeadDays)
        let resolvedTimeMinutes = minutesFromMidnight(for: notificationTime)
        let resolvedLeadKm = parsedLeadKm

        let intervalToSync: MaintenanceInterval

        switch mode {
        case .create(let template):
            guard let vehicle else { return }
            let newInterval = MaintenanceInterval(
                title: cleanedTitle,
                templateID: template.id,
                intervalKm: resolvedIntervalKm,
                intervalMonths: resolvedIntervalMonths,
                lastDoneDate: resolvedLastDate,
                lastDoneOdometerKm: resolvedLastOdometer,
                notificationsEnabled: notificationsEnabled,
                notificationsByDateEnabled: notificationsByDateEnabled,
                notificationsByMileageEnabled: notificationsByMileageEnabled,
                notificationLeadDays: resolvedLeadDays,
                notificationLeadKm: resolvedLeadKm,
                notificationTimeMinutes: resolvedTimeMinutes,
                notificationRepeat: notificationRepeat,
                notes: nil,
                isEnabled: isEnabled,
                vehicle: vehicle
            )
            vehicle.maintenanceIntervals.append(newInterval)
            intervalToSync = newInterval
        case .edit(let interval):
            interval.title = cleanedTitle
            interval.intervalKm = resolvedIntervalKm
            interval.intervalMonths = resolvedIntervalMonths
            interval.lastDoneDate = resolvedLastDate
            interval.lastDoneOdometerKm = resolvedLastOdometer
            interval.notificationsEnabled = notificationsEnabled
            interval.notificationsByDateEnabled = notificationsByDateEnabled
            interval.notificationsByMileageEnabled = notificationsByMileageEnabled
            interval.notificationLeadDays = resolvedLeadDays
            interval.notificationLeadKm = resolvedLeadKm
            interval.notificationTimeMinutes = resolvedTimeMinutes
            interval.notificationRepeat = notificationRepeat
            interval.isEnabled = isEnabled
            intervalToSync = interval
        }

        do { try modelContext.save() } catch { print("Failed to save reminder: \(error)") }

        Task {
            await MaintenanceNotifications.sync(
                intervalID: intervalToSync.id,
                title: intervalToSync.title,
                vehicleName: intervalToSync.vehicle?.name,
                dueDate: intervalToSync.nextDueDate(),
                nextDueKm: intervalToSync.nextDueKm(currentKm: suggestedOdometerKm),
                currentKm: suggestedOdometerKm,
                notificationsEnabled: intervalToSync.notificationsEnabled,
                notificationsByDateEnabled: intervalToSync.notificationsByDateEnabled,
                notificationsByMileageEnabled: intervalToSync.notificationsByMileageEnabled,
                leadDays: intervalToSync.notificationLeadDays,
                leadKm: intervalToSync.notificationLeadKm,
                timeMinutes: intervalToSync.notificationTimeMinutes,
                repeatRule: intervalToSync.notificationRepeat,
                isEnabled: intervalToSync.isEnabled
            )
        }

        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }
}
