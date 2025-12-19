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
                    "Нет интервалов обслуживания",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Добавьте интервалы для отслеживания замены масла, фильтров, ремней и других работ")
                )
            } else {
                ForEach(intervals) { interval in
                    MaintenanceIntervalRow(interval: interval, currentKm: currentOdometerKm)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(interval)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingInterval = interval
                            } label: {
                                Label("Править", systemImage: "pencil")
                            }
                            .tint(.blue)
                            
                            Button {
                                markAsDone(interval)
                            } label: {
                                Label("Выполнено", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                }
            }
        } header: {
            HStack {
                Text("Интервалы обслуживания")
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
        entry.notes = "Плановое обслуживание"
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
                return "Просрочено на \(-kmLeft) км"
            }
            return "Осталось \(kmLeft) км"
        }
        
        if let nextDate = interval.nextDueDate() {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
            if days < 0 {
                return "Просрочено на \(-days) дн"
            }
            return "Осталось \(days) дн"
        }
        
        return "Не настроено"
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
                    Text("Отключено")
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
                        Label("Каждые \(intervalKm) км", systemImage: "road.lanes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let intervalMonths = interval.intervalMonths {
                        Label("Каждые \(intervalMonths) мес", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let lastDate = interval.lastDoneDate {
                    Text("Последний раз: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
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
                Section("Основное") {
                    TextField("Название", text: $title)
                        .autocorrectionDisabled()
                    TextField("Интервал, км", text: $intervalKm)
                        .keyboardType(.numberPad)
                    TextField("Интервал, месяцев", text: $intervalMonths)
                        .keyboardType(.numberPad)
                }
                
                Section("Заметки") {
                    TextField("Заметки", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Новый интервал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        let interval = MaintenanceInterval(
                            title: title.isEmpty ? "Обслуживание" : title,
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
                Section("Основное") {
                    TextField("Название", text: $title)
                        .autocorrectionDisabled()
                    TextField("Интервал, км", text: $intervalKm)
                        .keyboardType(.numberPad)
                    TextField("Интервал, месяцев", text: $intervalMonths)
                        .keyboardType(.numberPad)
                    Toggle("Активен", isOn: $isEnabled)
                }
                
                Section("Заметки") {
                    TextField("Заметки", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Править интервал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
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
