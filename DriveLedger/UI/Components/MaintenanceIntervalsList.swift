//
//  MaintenanceIntervalsList.swift
//  DriveLedger
//

import SwiftUI
import SwiftData

struct MaintenanceIntervalsList: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var vehicle: Vehicle
    
    @State private var showAddInterval = false
    @State private var editingInterval: MaintenanceInterval?
    
    private var intervals: [MaintenanceInterval] {
        vehicle.maintenanceIntervals.sorted {
            if $0.isEnabled != $1.isEnabled { return $0.isEnabled && !$1.isEnabled }
            return $0.title < $1.title
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
                ContentUnavailableView(
                    String(localized: "maintenance.empty.title"),
                    systemImage: "wrench.and.screwdriver",
                    description: Text(String(localized: "maintenance.empty.description"))
                )
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
                            .tint(.blue)
                            
                            Button {
                                markAsDone(interval)
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
                    showAddInterval = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddInterval) {
            AddMaintenanceIntervalSheet(vehicle: vehicle)
        }
        .sheet(item: $editingInterval) { interval in
            EditMaintenanceIntervalSheet(interval: interval)
        }
    }
    
    private func markAsDone(_ interval: MaintenanceInterval) {
        interval.lastDoneDate = Date()
        interval.lastDoneOdometerKm = currentOdometerKm
        
        // Optionally create a service entry
        let entry = LogEntry(kind: .service, vehicle: vehicle)
        entry.serviceTitle = interval.title
        entry.date = Date()
        entry.odometerKm = currentOdometerKm
        entry.notes = String(localized: "maintenance.entry.plannedNote")
        modelContext.insert(entry)
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
        if let kmLeft = interval.kmUntilDue(currentKm: currentKm) {
            if kmLeft < 0 {
                return String.localizedStringWithFormat(
                    String(localized: "maintenance.status.overdue.km"),
                    -kmLeft
                )
            }
            return String.localizedStringWithFormat(
                String(localized: "maintenance.status.remaining.km"),
                kmLeft
            )
        }
        
        if let nextDate = interval.nextDueDate() {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
            if days < 0 {
                return String.localizedStringWithFormat(
                    String(localized: "maintenance.status.overdue.days"),
                    -days
                )
            }
            return String.localizedStringWithFormat(
                String(localized: "maintenance.status.remaining.days"),
                days
            )
        }
        
        return String(localized: "maintenance.status.notConfigured")
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
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "maintenance.lastDone"),
                            lastDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    )
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
    
    @State private var title = ""
    @State private var intervalKm = ""
    @State private var intervalMonths = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "maintenance.section.main")) {
                    TextField(String(localized: "maintenance.field.title"), text: $title)
                        .autocorrectionDisabled()
                    TextField(String(localized: "maintenance.field.intervalKm"), text: $intervalKm)
                        .keyboardType(.numberPad)
                    TextField(String(localized: "maintenance.field.intervalMonths"), text: $intervalMonths)
                        .keyboardType(.numberPad)
                }
                
                Section(String(localized: "maintenance.section.notes")) {
                    TextField(String(localized: "maintenance.field.notes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
                        let interval = MaintenanceInterval(
                            title: title.isEmpty ? String(localized: "maintenance.defaultTitle") : title,
                            intervalKm: Int(intervalKm),
                            intervalMonths: Int(intervalMonths),
                            notes: notes.isEmpty ? nil : notes,
                            vehicle: vehicle
                        )
                        modelContext.insert(interval)
                        dismiss()
                    }
                    .disabled(title.isEmpty && intervalKm.isEmpty && intervalMonths.isEmpty)
                }
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "maintenance.section.main")) {
                    TextField(String(localized: "maintenance.field.title"), text: $title)
                        .autocorrectionDisabled()
                    TextField(String(localized: "maintenance.field.intervalKm"), text: $intervalKm)
                        .keyboardType(.numberPad)
                    TextField(String(localized: "maintenance.field.intervalMonths"), text: $intervalMonths)
                        .keyboardType(.numberPad)
                    Toggle(String(localized: "maintenance.field.active"), isOn: $isEnabled)
                }
                
                Section(String(localized: "maintenance.section.notes")) {
                    TextField(String(localized: "maintenance.field.notes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
                        dismiss()
                    }
                    .disabled(title.isEmpty && intervalKm.isEmpty && intervalMonths.isEmpty)
                }
            }
            .onAppear {
                title = interval.title
                intervalKm = interval.intervalKm.map(String.init) ?? ""
                intervalMonths = interval.intervalMonths.map(String.init) ?? ""
                notes = interval.notes ?? ""
                isEnabled = interval.isEnabled
            }
        }
    }
}
