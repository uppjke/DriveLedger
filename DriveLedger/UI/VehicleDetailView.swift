//
//  VehicleDetailView.swift
//  DriveLedger
//

import SwiftUI
import Foundation
import SwiftData

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var vehicle: Vehicle
    let onAddEntry: (Vehicle, LogEntryKind?) -> Void

    private var swipeActionTintOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.5
    }

    private var entries: [LogEntry] {
        // Stable ordering avoids UI jitter when dates are equal and keeps signatures predictable.
        vehicle.entries.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            let a = $0.odometerKm ?? Int.min
            let b = $1.odometerKm ?? Int.min
            if a != b { return a > b }
            return $0.id.uuidString > $1.id.uuidString
        }
    }

    // Month-based journal navigation
    @State private var selectedMonthStart: Date
    @State private var didSetInitialMonth = false
    @State private var editingEntry: LogEntry?
    @State private var analyticsRefreshNonce = UUID()

    private enum DetailTab: CaseIterable, Identifiable {
        case journal
        case analytics

        var id: Self { self }

        var title: String {
            switch self {
            case .journal:
                return String(localized: "tab.journal")
            case .analytics:
                return String(localized: "tab.analytics")
            }
        }
    }

    @State private var tab: DetailTab = .journal

    private var calendar: Calendar { .current }

    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    init(vehicle: Vehicle, onAddEntry: @escaping (Vehicle, LogEntryKind?) -> Void) {
        self.vehicle = vehicle
        self.onAddEntry = onAddEntry
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        _selectedMonthStart = State(initialValue: start)
    }

    /// Start (inclusive) and end (exclusive) of a month.
    private func monthRange(for monthStartDate: Date) -> (start: Date, end: Date) {
        let start = monthStart(for: monthStartDate)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }

    private func monthTitle(for monthStart: Date) -> String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private func monthEntries(for monthStart: Date) -> [LogEntry] {
        let range = monthRange(for: monthStart)
        return entries.filter { $0.date >= range.start && $0.date < range.end }
    }

    private func monthTotalCost(for monthStart: Date) -> Double {
        monthEntries(for: monthStart).compactMap { $0.totalCost }.reduce(0, +)
    }

    private func sectionTotalCost(_ entries: [LogEntry]) -> Double? {
        let costs = entries.compactMap { $0.totalCost }
        guard !costs.isEmpty else { return nil }
        return costs.reduce(0, +)
    }

    private var availableMonthStarts: [Date] {
        let current = monthStart(for: Date())
        let oldest = entries.map { $0.date }.min().map(monthStart(for:)) ?? current
        let newest = entries.map { $0.date }.max().map(monthStart(for:)) ?? current
        let minBase = min(oldest, current)
        let maxBase = max(newest, current)

        // Give some slack so you can swipe into empty months a bit.
        let minMonth = calendar.date(byAdding: .month, value: -12, to: minBase) ?? minBase
        let maxMonth = calendar.date(byAdding: .month, value: 12, to: maxBase) ?? maxBase

        var months: [Date] = []
        var cursor = monthStart(for: minMonth)
        let end = monthStart(for: maxMonth)
        while cursor <= end {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? cursor
            if months.count > 600 { break }
        }
        return months
    }

    private func shiftSelectedMonth(by months: Int) {
        let next = calendar.date(byAdding: .month, value: months, to: selectedMonthStart) ?? selectedMonthStart
        selectedMonthStart = monthStart(for: next)
    }

    /// Поля, влияющие на расход топлива. Меняются — делаем пересчёт + обновляем AnalyticsView.
    private var analyticsSignature: String {
        entries.map {
            "\($0.id.uuidString)|\($0.kindRaw)|\($0.date.timeIntervalSinceReferenceDate)|\($0.odometerKm ?? -1)|\($0.fuelLiters ?? -1)|\($0.fuelFillKindRaw ?? "")"
        }
        .joined(separator: ";")
    }

    private var monthEntries: [LogEntry] {
        monthEntries(for: selectedMonthStart)
    }

    private var monthTotalCost: Double {
        monthTotalCost(for: selectedMonthStart)
    }

    private struct EntrySection: Identifiable {
        var id: String { title }
        let title: String
        let entries: [LogEntry]
    }

    private var monthSections: [EntrySection] {
        // Preserve timeline ordering inside each section.
        let groups = Dictionary(grouping: monthEntries) { $0.kind }

        func section(_ kind: LogEntryKind, title: String) -> EntrySection? {
            guard let items = groups[kind], !items.isEmpty else { return nil }
            return EntrySection(title: title, entries: items)
        }

        // “Авто-логика”: обслуживание/заправки выше, заметки — ниже.
        return [
            section(.fuel, title: String(localized: "journal.section.fuel")),
            section(.service, title: String(localized: "journal.section.service")),
            section(.tireService, title: String(localized: "journal.section.tireService")),
            section(.tolls, title: String(localized: "journal.section.tolls")),
            section(.parking, title: String(localized: "journal.section.parking")),
            section(.carwash, title: String(localized: "journal.section.carwash")),
            section(.fines, title: String(localized: "journal.section.fines")),
            section(.purchase, title: String(localized: "journal.section.purchase")),
            section(.odometer, title: String(localized: "journal.section.odometer")),
            section(.note, title: String(localized: "journal.section.note"))
        ].compactMap { $0 }
    }

    private var lastServiceEntry: LogEntry? {
        entries.first(where: { $0.kind == .service })
    }

    private var lastFuelEntry: LogEntry? {
        entries.first(where: { $0.kind == .fuel })
    }

    private var lastCarwashEntry: LogEntry? {
        entries.first(where: { $0.kind == .carwash })
    }

    private func serviceSnippet(_ entry: LogEntry) -> String? {
        let title = entry.serviceTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let title, !title.isEmpty { return title }
        let details = entry.serviceDetails?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let details, !details.isEmpty { return details }
        return nil
    }

    /// Детерминированный порядок для FuelConsumption (дата ↑, пробег ↑, id ↑).
    private var entriesForFuelCalc: [LogEntry] {
        entries.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            let a = $0.odometerKm ?? Int.min
            let b = $1.odometerKm ?? Int.min
            if a != b { return a < b }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func recalcFuelAndRefresh() {
        FuelConsumption.recalculateAll(existingEntries: entriesForFuelCalc)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            assertionFailure("Failed to save after fuel recalculation: \(error)")
            #endif
            print("Failed to save after fuel recalculation: \(error)")
        }
        analyticsRefreshNonce = UUID()
    }

    @ViewBuilder
    private func monthHeaderCenter(for monthStart: Date) -> some View {
        VStack(spacing: 4) {
            Text(monthTitle(for: monthStart))
                .font(.headline)

            HStack(spacing: 8) {
                Text("\(String(localized: "journal.month.summary.cost")) \(DLFormatters.currency(monthTotalCost(for: monthStart)))")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        NavigationStack {
            List {
                Section { summary }

                Section {
                    Picker(String(localized: "tab.section"), selection: $tab) {
                        ForEach(DetailTab.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if tab == .journal {
                    Section {
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.snappy) { shiftSelectedMonth(by: -1) }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.headline)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "journal.action.prevMonth"))

                            TabView(selection: $selectedMonthStart) {
                                ForEach(availableMonthStarts, id: \.self) { m in
                                    monthHeaderCenter(for: m)
                                        .tag(m)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .frame(height: 44)
                            .onChange(of: selectedMonthStart) { _, newValue in
                                // Keep the selection normalized.
                                selectedMonthStart = monthStart(for: newValue)
                            }

                            Button {
                                withAnimation(.snappy) { shiftSelectedMonth(by: 1) }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.headline)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "journal.action.nextMonth"))
                        }
                    }

                    Section(String(localized: "journal.section.title")) {
                        if monthEntries.isEmpty {
                            ContentUnavailableView(
                                String(localized: "entries.empty.title"),
                                systemImage: "list.bullet.rectangle",
                                description: Text(String(localized: "entries.empty.description"))
                            )
                        } else {
                            ForEach(monthSections) { section in
                                Section {
                                    ForEach(section.entries) { entry in
                                        EntryRow(entry: entry)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button {
                                                    deleteEntry(entry)
                                                } label: {
                                                    Label(String(localized: "action.delete"), systemImage: "trash")
                                                }
                                                .tint(Color(uiColor: .systemRed).opacity(swipeActionTintOpacity))
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                                Button {
                                                    editingEntry = entry
                                                } label: {
                                                    Label(String(localized: "action.edit"), systemImage: "pencil")
                                                }
                                                .tint(Color(uiColor: .systemBlue).opacity(swipeActionTintOpacity))
                                            }
                                    }
                                } header: {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(section.title)
                                        Spacer(minLength: 12)
                                        if let total = sectionTotalCost(section.entries) {
                                            Text(DLFormatters.currency(total))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                } else {
                    AnalyticsView(entries: entries)
                        .id("\(analyticsSignature)|\(analyticsRefreshNonce.uuidString)")
                }
            }
            .navigationTitle(vehicle.name)
            .accessibilityIdentifier("vehicle.detail.\(vehicle.id.uuidString)")
            // Month switching uses a horizontal page swipe; prevent it from being interpreted as a back swipe.
            .background(InteractivePopGestureDisabler(disabled: tab == .journal))
            .onAppear {
                // Always start with the current month on first open.
                guard !didSetInitialMonth else { return }
                selectedMonthStart = monthStart(for: Date())
                didSetInitialMonth = true
            }
            // Ключевое: при любой правке odo/liters/fillKind/типа — пересчитать и обновить аналитику
            .onChange(of: analyticsSignature) { _, _ in
                recalcFuelAndRefresh()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        MaintenanceHubView(vehicle: vehicle, showsCloseButton: false)
                    } label: {
                        Image(systemName: "wrench.and.screwdriver")
                            .symbolRenderingMode(.hierarchical)
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(String(localized: "tab.maintenance"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onAddEntry(vehicle, .odometer)
                    } label: {
                        Image(systemName: "speedometer")
                            .symbolRenderingMode(.hierarchical)
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(String(localized: "entry.kind.odometer"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onAddEntry(vehicle, nil)
                    } label: {
                        Image(systemName: "plus")
                            .symbolRenderingMode(.hierarchical)
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(String(localized: "action.add"))
                }
            }
        }
        .sheet(item: $editingEntry, onDismiss: {
            // Подстраховка: после закрытия редактора точно пересчитываем и обновляем аналитику
            recalcFuelAndRefresh()
        }) { entry in
            EditEntrySheet(entry: entry, existingEntries: entriesForFuelCalc)
        }
    }

    private func deleteEntry(_ entry: LogEntry) {
        let remaining = entries
            .filter { $0.id != entry.id }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                let a = $0.odometerKm ?? Int.min
                let b = $1.odometerKm ?? Int.min
                if a != b { return a < b }
                return $0.id.uuidString < $1.id.uuidString
            }

        modelContext.delete(entry)
        FuelConsumption.recalculateAll(existingEntries: remaining)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            assertionFailure("Failed to save after deleting entry: \(error)")
            #endif
            print("Failed to save after deleting entry: \(error)")
        }
        analyticsRefreshNonce = UUID()

        let currentKm = remaining.compactMap { $0.odometerKm }.max() ?? vehicle.initialOdometerKm
        Task {
            await MaintenanceNotifications.syncAll(for: vehicle, currentKm: currentKm)
        }
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(s.date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                            .font(.headline)
                        if let snippet = serviceSnippet(s) {
                            Text(snippet)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            if let w = lastCarwashEntry {
                HStack {
                    Label("Последняя мойка", systemImage: "drop")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(w.date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                        .font(.headline)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
