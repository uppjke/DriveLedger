//
//  VehicleDetailView.swift
//  DriveLedger
//

import SwiftUI
import Foundation
import SwiftData

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var vehicle: Vehicle
    let onAddEntry: () -> Void

    private var entries: [LogEntry] {
        vehicle.entries.sorted { $0.date > $1.date }
    }

    private enum EntryFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case fuel = "Заправки"
        case service = "ТО"
        case purchase = "Покупки"
        var id: String { rawValue }
    }

    @State private var filter: EntryFilter = .all
    @State private var exportURL: URL?
    @State private var editingEntry: LogEntry?

    private enum DetailTab: String, CaseIterable, Identifiable {
        case journal = "Журнал"
        case analytics = "Аналитика"
        var id: String { rawValue }
    }

    @State private var tab: DetailTab = .journal

    // чтобы CSV пересобирался не только при изменении количества записей,
    // но и при правках суммы/пробега/даты/типа
    private var exportSignature: String {
        entries.map {
            "\($0.id.uuidString)|\($0.kindRaw)|\($0.date.timeIntervalSinceReferenceDate)|\($0.totalCost ?? -1)|\($0.odometerKm ?? -1)"
        }
        .joined(separator: ";")
    }

    private var filteredEntries: [LogEntry] {
        switch filter {
        case .all:
            return entries
        case .fuel:
            return entries.filter { $0.kind == .fuel }
        case .service:
            return entries.filter { $0.kind == .service }
        case .purchase:
            return entries.filter { $0.kind == .purchase }
        }
    }

    private var last30DaysTotal: Double {
        let from = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return entries
            .filter { $0.date >= from }
            .compactMap { $0.totalCost }
            .reduce(0, +)
    }

    private var lastServiceEntry: LogEntry? {
        entries.first(where: { $0.kind == .service })
    }

    private var lastFuelEntry: LogEntry? {
        entries.first(where: { $0.kind == .fuel })
    }

    var body: some View {
        NavigationStack {
            List {
                Section { summary }

                Section {
                    Picker("Раздел", selection: $tab) {
                        ForEach(DetailTab.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if tab == .journal {
                    Section {
                        Picker("Фильтр", selection: $filter) {
                            ForEach(EntryFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Журнал") {
                        if filteredEntries.isEmpty {
                            ContentUnavailableView(
                                "Пока нет записей",
                                systemImage: "list.bullet.rectangle",
                                description: Text("Добавьте заправку, обслуживание или покупку")
                            )
                        } else {
                            ForEach(filteredEntries) { entry in
                                EntryRow(entry: entry)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteEntry(entry)
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            editingEntry = entry
                                        } label: {
                                            Label("Править", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                } else {
                    AnalyticsView(entries: entries)
                }
            }
            .navigationTitle(vehicle.name)
            .task(id: exportSignature) {
                // allow SwiftUI to cancel/restart when exportSignature changes rapidly
                exportURL = nil

                let vehicleName = vehicle.name
                let snapshot = entries

                let url = await Task.detached(priority: .utility) {
                    CSVExport.makeVehicleCSVExportURL(vehicleName: vehicleName, entries: snapshot)
                }.value

                exportURL = url
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let url = exportURL {
                        ShareLink(
                            item: url,
                            preview: SharePreview((vehicle.name.isEmpty ? "DriveLedger" : vehicle.name) + ".csv")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    } else {
                        Button {} label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(true)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onAddEntry) {
                        Label("Добавить", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            let entriesForRecalc = entries
                .sorted {
                    if $0.date != $1.date { return $0.date < $1.date }
                    let a = $0.odometerKm ?? Int.min
                    let b = $1.odometerKm ?? Int.min
                    return a < b
                }

            EditEntrySheet(entry: entry, existingEntries: entriesForRecalc)
        }
    }

    private func deleteEntry(_ entry: LogEntry) {
        // заранее считаем "что останется", чтобы пересчитать корректно даже до обновления SwiftData/relationship
        let remaining = entries
            .filter { $0.id != entry.id }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                let a = $0.odometerKm ?? Int.min
                let b = $1.odometerKm ?? Int.min
                return a < b
            }

        modelContext.delete(entry)
        FuelConsumption.recalculateAll(existingEntries: remaining)
        try? modelContext.save()
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(vehicle.displaySubtitle.isEmpty ? "" : vehicle.displaySubtitle)
                    .foregroundStyle(.secondary)
                Spacer()
                if let last = entries.compactMap(\.odometerKm).first {
                    Text("\(last) км").font(.headline)
                } else if let initial = vehicle.initialOdometerKm {
                    Text("\(initial) км").font(.headline)
                }
            }

            HStack {
                Label("Расходы · 30 дней", systemImage: "chart.bar")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(last30DaysTotal, format: .currency(code: DLFormatters.currencyCode))
                    .font(.headline)
            }

            if let e = lastFuelEntry, let liters = e.fuelLiters {
                HStack {
                    Label("Последняя заправка", systemImage: "fuelpump")
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(DLFormatters.liters(liters)) л").font(.headline)
                        if let p = e.fuelPricePerLiter {
                            Text("\(DLFormatters.price(p)) /л")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let s = lastServiceEntry {
                HStack {
                    Label("Последнее ТО", systemImage: "wrench.and.screwdriver")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(s.date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                        .font(.headline)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

