//
//  ContentView.swift
//  DriveLedger
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Vehicle.createdAt, order: .forward)
    private var vehicles: [Vehicle]

    private enum SidebarSelection: Hashable {
        case vehicle(UUID)
    }

    @State private var selection: SidebarSelection?
    @State private var showAddVehicle = false
    private struct AddEntryContext: Identifiable {
        let id = UUID()
        let vehicle: Vehicle
        let initialKind: LogEntryKind?
        let allowedKinds: [LogEntryKind]
    }

    @State private var addEntryContext: AddEntryContext?
    @State private var editingVehicle: Vehicle?
    @State private var detailsVehicle: Vehicle?

    @State private var backupDocument: DriveLedgerBackupDocument?
    @State private var showExportBackup = false
    @State private var showImportBackup = false
    @State private var showBackupAlert = false
    @State private var backupAlertTitle = ""
    @State private var backupAlertMessage = ""

    @State private var showCopyToast = false
    @State private var copyToastMessage = ""

    @State private var didInitialNotificationSync = false

    private var swipeActionTintOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.5
    }

    private var selectedVehicle: Vehicle? {
        guard case .vehicle(let id) = selection else { return nil }
        return vehicles.first(where: { $0.id == id })
    }
    
    var body: some View {
        root
        .overlay(alignment: .top) {
            copyToastOverlay
        }
        .task {
            guard !didInitialNotificationSync else { return }
            didInitialNotificationSync = true

            // Best-effort: schedule existing maintenance reminders (date-based), and evaluate mileage rules
            // using the current odometer snapshot available in the app.
            for v in vehicles {
                let currentKm = v.entries.compactMap { $0.odometerKm }.max() ?? v.initialOdometerKm
                await MaintenanceNotifications.syncAll(for: v, currentKm: currentKm)
            }
        }
        .fileExporter(
            isPresented: $showExportBackup,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "DriveLedger.backup.json"
        ) { result in
            switch result {
            case .success:
                backupAlertTitle = String(localized: "backup.export.success.title")
                backupAlertMessage = String(localized: "backup.export.success.message")
                showBackupAlert = true
            case .failure(let error):
                backupAlertTitle = String(localized: "backup.error.title")
                backupAlertMessage = error.localizedDescription
                showBackupAlert = true
            }
        }
        .fileImporter(
            isPresented: $showImportBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else {
                    return
                }
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let summary = try DriveLedgerBackupCodec.importData(data, into: modelContext)

                backupAlertTitle = String(localized: "backup.import.success.title")
                backupAlertMessage = String(
                    format: String(localized: "backup.import.success.message"),
                    summary.vehiclesUpserted,
                    summary.entriesUpserted
                )
                showBackupAlert = true

                if selection == nil, let first = vehicles.first {
                    selection = .vehicle(first.id)
                }

                Task {
                    for v in vehicles {
                        let currentKm = v.entries.compactMap { $0.odometerKm }.max() ?? v.initialOdometerKm
                        await MaintenanceNotifications.syncAll(for: v, currentKm: currentKm)
                    }
                }
            } catch {
                backupAlertTitle = String(localized: "backup.error.title")
                backupAlertMessage = error.localizedDescription
                showBackupAlert = true
            }
        }
        .alert(backupAlertTitle, isPresented: $showBackupAlert) {
            Button(String(localized: "action.ok")) {}
        } message: {
            Text(backupAlertMessage)
        }
        .sheet(isPresented: $showAddVehicle) {
            AddVehicleSheet { vehicle in
                modelContext.insert(vehicle)
                // Wheel sets created during vehicle creation are separate models.
                for ws in vehicle.wheelSets {
                    modelContext.insert(ws)
                }
                selection = .vehicle(vehicle.id)
            }
        }
        .sheet(item: $addEntryContext) { ctx in
            AddEntrySheetHost(vehicle: ctx.vehicle, allowedKinds: ctx.allowedKinds, initialKind: ctx.initialKind) { entry in
                modelContext.insert(entry)
            }
        }
        .sheet(item: $editingVehicle) { v in
            EditVehicleSheet(vehicle: v)
        }
        .sheet(item: $detailsVehicle) { v in
            VehicleDetailsSheet(vehicle: v)
        }
    }

    @ViewBuilder
    private var root: some View {
        if horizontalSizeClass == .compact {
            compactRoot
        } else {
            splitRoot
        }
    }

    private var splitRoot: some View {
        NavigationSplitView {
            splitSidebar
        } detail: {
            detail
        }
    }

    private var compactRoot: some View {
        NavigationStack {
            compactVehiclePicker
        }
    }

    private func vehicleRowContent(for vehicle: Vehicle) -> some View {
        HStack(alignment: .center, spacing: 12) {
            let style = VehicleBodyStyleOption(rawValue: vehicle.bodyStyle ?? "")
            let symbol = style?.symbolName
                ?? (vehicle.iconSymbol?.isEmpty == false ? vehicle.iconSymbol! : "car.fill")

            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.name)
                        .font(.headline)

                    if !vehicle.displaySubtitle.isEmpty {
                        Text(vehicle.displaySubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let vin = vehicle.vin?.trimmingCharacters(in: .whitespacesAndNewlines), !vin.isEmpty {
                    HStack(spacing: 0) {
                        Text(vin.uppercased())
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        .separator,
                                        style: StrokeStyle(lineWidth: 0.6, dash: [4, 3])
                                    )
                            )
                            .foregroundStyle(.secondary)
                            .contentShape(Capsule(style: .continuous))
                            .onTapGesture {
                                copyToPasteboard(vin)
                            }
                            .accessibilityLabel("VIN")
                            .accessibilityValue(vin)

                        Spacer(minLength: 0)
                    }
                }
            }

            Spacer(minLength: 0)

            if let plate = vehicle.licensePlate?.trimmingCharacters(in: .whitespacesAndNewlines), !plate.isEmpty {
                let parts = splitLicensePlate(plate)
                HStack(spacing: 6) {
                    Text(parts.main)
                        .font(.subheadline.monospaced())

                    if let region = parts.region {
                        Divider()
                            .frame(height: 16)

                        Text(region)
                            .font(.caption.monospacedDigit())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 0.5)
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private func splitLicensePlate(_ raw: String) -> (main: String, region: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", nil) }

        let cleaned = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        var suffixDigitsReversed: [Character] = []
        suffixDigitsReversed.reserveCapacity(4)
        for ch in cleaned.reversed() {
            if ch.isNumber {
                suffixDigitsReversed.append(ch)
            } else {
                break
            }
        }

        let suffixDigits = String(suffixDigitsReversed.reversed())
        guard (2...3).contains(suffixDigits.count) else {
            return (cleaned, nil)
        }

        let cut = cleaned.index(cleaned.endIndex, offsetBy: -suffixDigits.count)
        let main = String(cleaned[..<cut])
        guard !main.isEmpty else { return (cleaned, nil) }
        return (main, suffixDigits)
    }

    private func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        copyToastMessage = String(localized: "toast.copied")
        withAnimation(.easeOut(duration: 0.15)) {
            showCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.2)) {
                showCopyToast = false
            }
        }
    }

    @ViewBuilder
    private var copyToastOverlay: some View {
        if showCopyToast {
            Text(copyToastMessage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.separator, lineWidth: 0.5)
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
        }
    }

    private func deleteVehicle(_ vehicle: Vehicle) {
        modelContext.delete(vehicle)

        if case .vehicle(let currentID) = selection, vehicle.id == currentID {
            if let next = vehicles.first(where: { $0.id != currentID }) {
                selection = .vehicle(next.id)
            } else {
                selection = nil
            }
        }
    }

    private var splitSidebar: some View {
        List(selection: $selection) {
            Section(String(localized: "vehicles.section.title")) {
                ForEach(vehicles) { vehicle in
                    vehicleRowContent(for: vehicle)
                        .tag(SidebarSelection.vehicle(vehicle.id) as SidebarSelection?)
                        .accessibilityIdentifier("sidebar.vehicle.\(vehicle.id.uuidString)")
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if vehicle.hasExtraDetails {
                            Button {
                                detailsVehicle = vehicle
                            } label: {
                                Label(String(localized: "vehicle.action.details"), systemImage: "info.circle")
                            }
                            .tint(Color(uiColor: .systemGray).opacity(swipeActionTintOpacity))
                        }

                        Button {
                            editingVehicle = vehicle
                        } label: {
                            Label(String(localized: "action.edit"), systemImage: "pencil")
                        }
                        .tint(Color(uiColor: .systemBlue).opacity(swipeActionTintOpacity))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            deleteVehicle(vehicle)
                        } label: {
                            Label(String(localized: "action.delete"), systemImage: "trash")
                        }
                        .tint(Color(uiColor: .systemRed).opacity(swipeActionTintOpacity))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "app.title"))
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button {
                    showAddVehicle = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "action.addVehicle"))
                .accessibilityIdentifier("vehicles.add.fab")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        do {
                            let data = try DriveLedgerBackupCodec.exportData(from: modelContext)
                            backupDocument = DriveLedgerBackupDocument(data: data)
                            showExportBackup = true
                        } catch {
                            backupAlertTitle = String(localized: "backup.error.title")
                            backupAlertMessage = error.localizedDescription
                            showBackupAlert = true
                        }
                    } label: {
                        Label(String(localized: "action.backup.export"), systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImportBackup = true
                    } label: {
                        Label(String(localized: "action.backup.import"), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityLabel(String(localized: "action.more"))
                }
            }
        }
    }

    private var compactVehiclePicker: some View {
        List {
            Section(String(localized: "vehicles.section.title")) {
                ForEach(vehicles) { vehicle in
                    NavigationLink {
                        VehicleDetailView(
                            vehicle: vehicle,
                            onAddEntry: { vehicle, initialKind in
                                selection = .vehicle(vehicle.id)
                                if initialKind == .odometer {
                                    addEntryContext = AddEntryContext(vehicle: vehicle, initialKind: .odometer, allowedKinds: [.odometer])
                                } else {
                                    addEntryContext = AddEntryContext(vehicle: vehicle, initialKind: nil, allowedKinds: [.fuel, .service, .tireService, .purchase, .tolls, .fines, .carwash, .parking])
                                }
                            }
                        )
                        .onAppear {
                            selection = .vehicle(vehicle.id)
                        }
                    } label: {
                        vehicleRowContent(for: vehicle)
                    }
                    .accessibilityIdentifier("sidebar.vehicle.\(vehicle.id.uuidString)")
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if vehicle.hasExtraDetails {
                            Button {
                                detailsVehicle = vehicle
                            } label: {
                                Label(String(localized: "vehicle.action.details"), systemImage: "info.circle")
                            }
                            .tint(Color(uiColor: .systemGray).opacity(swipeActionTintOpacity))
                        }

                        Button {
                            editingVehicle = vehicle
                        } label: {
                            Label(String(localized: "action.edit"), systemImage: "pencil")
                        }
                        .tint(Color(uiColor: .systemBlue).opacity(swipeActionTintOpacity))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            deleteVehicle(vehicle)
                        } label: {
                            Label(String(localized: "action.delete"), systemImage: "trash")
                        }
                        .tint(Color(uiColor: .systemRed).opacity(swipeActionTintOpacity))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "app.title"))
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button {
                    showAddVehicle = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "action.addVehicle"))
                .accessibilityIdentifier("vehicles.add.fab")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        do {
                            let data = try DriveLedgerBackupCodec.exportData(from: modelContext)
                            backupDocument = DriveLedgerBackupDocument(data: data)
                            showExportBackup = true
                        } catch {
                            backupAlertTitle = String(localized: "backup.error.title")
                            backupAlertMessage = error.localizedDescription
                            showBackupAlert = true
                        }
                    } label: {
                        Label(String(localized: "action.backup.export"), systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImportBackup = true
                    } label: {
                        Label(String(localized: "action.backup.import"), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityLabel(String(localized: "action.more"))
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .vehicle:
            if let vehicle = selectedVehicle {
                VehicleDetailView(vehicle: vehicle, onAddEntry: { vehicle, initialKind in
                    if initialKind == .odometer {
                        addEntryContext = AddEntryContext(vehicle: vehicle, initialKind: .odometer, allowedKinds: [.odometer])
                    } else {
                        addEntryContext = AddEntryContext(vehicle: vehicle, initialKind: nil, allowedKinds: [.fuel, .service, .tireService, .purchase, .tolls, .fines, .carwash, .parking])
                    }
                })
            } else {
                ContentUnavailableView(
                    String(localized: "vehicles.empty.title"),
                    systemImage: "car",
                    description: Text(String(localized: "vehicles.empty.description"))
                )
            }
        case nil:
            ContentUnavailableView(
                String(localized: "vehicles.empty.title"),
                systemImage: "car",
                description: Text(String(localized: "vehicles.empty.description"))
            )
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button {
                        showAddVehicle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "action.addVehicle"))
                    .accessibilityIdentifier("vehicles.add.fab")
                }
            }
        }
    }

    private func deleteVehicles(offsets: IndexSet) {
        let deleting = offsets.map { vehicles[$0] }
        deleting.forEach { modelContext.delete($0) }

        if case .vehicle(let currentID) = selection,
           deleting.contains(where: { $0.id == currentID }) {
            if let next = vehicles.first(where: { $0.id != currentID }) {
                selection = .vehicle(next.id)
            } else {
                selection = nil
            }
        }
    }
}

private struct VehicleDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    private var trimmedMake: String? {
        let t = (vehicle.make ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var trimmedModel: String? {
        let t = (vehicle.model ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var trimmedGeneration: String? {
        let t = (vehicle.generation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var trimmedEngine: String? {
        let t = (vehicle.engine ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var trimmedPlate: String? {
        let t = (vehicle.licensePlate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var trimmedVIN: String? {
        let t = (vehicle.vin ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t.uppercased()
    }

    private var bodyStyleTitle: String? {
        guard let raw = vehicle.bodyStyle?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return VehicleBodyStyleOption(rawValue: raw)?.title ?? raw
    }

    private var colorTitle: String? {
        guard let raw = vehicle.colorName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return VehicleColorOption(rawValue: raw)?.title ?? raw
    }

    var body: some View {
        NavigationStack {
            Form {
                let currentKmFromEntries = vehicle.entries.compactMap { $0.odometerKm }.max()

                Section(String(localized: "vehicle.section.main")) {
                    if let make = trimmedMake {
                        LabeledContent(String(localized: "vehicle.field.make"), value: make)
                    }
                    if let model = trimmedModel {
                        LabeledContent(String(localized: "vehicle.field.model"), value: model)
                    }
                    if let plate = trimmedPlate {
                        LabeledContent(String(localized: "vehicle.field.plate"), value: plate)
                    }
                    if let vin = trimmedVIN {
                        LabeledContent(String(localized: "vehicle.field.vin"), value: vin)
                    }
                }

                Section(String(localized: "vehicle.section.details")) {
                    if let gen = trimmedGeneration {
                        LabeledContent(String(localized: "vehicle.field.generation"), value: gen)
                    }
                    if let year = vehicle.year {
                        LabeledContent(String(localized: "vehicle.field.year"), value: String(year))
                    }
                    if let engine = trimmedEngine {
                        LabeledContent(String(localized: "vehicle.field.engine"), value: engine)
                    }
                    if let body = bodyStyleTitle {
                        LabeledContent(String(localized: "vehicle.field.bodyStyle"), value: body)
                    }
                    if let color = colorTitle {
                        LabeledContent(String(localized: "vehicle.field.color"), value: color)
                    }
                }

                if currentKmFromEntries != nil || vehicle.initialOdometerKm != nil {
                    Section(String(localized: "vehicle.section.odometer")) {
                        if let current = currentKmFromEntries {
                            LabeledContent(String(localized: "vehicle.field.currentOdo"), value: String(current))
                        }
                        if let initial = vehicle.initialOdometerKm {
                            LabeledContent(String(localized: "vehicle.field.initialOdo"), value: String(initial))
                        }
                    }
                }

                Section(String(localized: "vehicle.section.wheels")) {
                    GlassCardRow(isActive: false) {
                        if let ws = vehicle.currentWheelSet {
                            WheelSetCardContent(
                                title: ws.autoName,
                                wheelSpecs: ws.wheelSpecs,
                                summary: ws.summary
                            )
                        } else {
                            HStack {
                                Text(String(localized: "vehicle.choice.notSet"))
                                Spacer()
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(String(localized: "vehicle.details.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.close")) { dismiss() }
                }
            }
        }
    }
}

