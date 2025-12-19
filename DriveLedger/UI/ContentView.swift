//
//  ContentView.swift
//  DriveLedger
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \Vehicle.createdAt, order: .forward)
    private var vehicles: [Vehicle]

    private enum SidebarSelection: Hashable {
        case vehicle(UUID)
    }

    @State private var selection: SidebarSelection?
    @State private var showAddVehicle = false
    @State private var showAddEntry = false
    @State private var editingVehicle: Vehicle?

    @State private var backupDocument: DriveLedgerBackupDocument?
    @State private var showExportBackup = false
    @State private var showImportBackup = false
    @State private var showBackupAlert = false
    @State private var backupAlertTitle = ""
    @State private var backupAlertMessage = ""

    private var selectedVehicle: Vehicle? {
        guard case .vehicle(let id) = selection else { return nil }
        return vehicles.first(where: { $0.id == id })
    }
    
    var body: some View {
        root
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
                selection = .vehicle(vehicle.id)
            }
        }
        .sheet(isPresented: $showAddEntry) {
            if let vehicle = selectedVehicle {
                AddEntrySheetHost(vehicle: vehicle) { entry in
                    modelContext.insert(entry)
                }
            } else {
                ContentUnavailableView(String(localized: "entries.add.requiresVehicle"), systemImage: "car")
                    .presentationDetents([.medium])
            }
        }
        .sheet(item: $editingVehicle) { v in
            EditVehicleSheet(vehicle: v)
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
        HStack(spacing: 12) {
            let style = VehicleBodyStyleOption(rawValue: vehicle.bodyStyle ?? "")
            let symbol = style?.symbolName
                ?? (vehicle.iconSymbol?.isEmpty == false ? vehicle.iconSymbol! : "car.fill")

            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.headline)

                if !vehicle.displaySubtitle.isEmpty {
                    Text(vehicle.displaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let plate = vehicle.licensePlate?.trimmingCharacters(in: .whitespacesAndNewlines), !plate.isEmpty {
                Text(plate.uppercased())
                    .font(.subheadline.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.secondary, lineWidth: 1)
                    )
                    .foregroundStyle(.secondary)
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
                        Button {
                            editingVehicle = vehicle
                        } label: {
                            Label(String(localized: "action.edit"), systemImage: "pencil")
                        }
                    }
                }
                .onDelete(perform: deleteVehicles)
            }
        }
        .navigationTitle(String(localized: "app.title"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddVehicle = true } label: {
                    Label(String(localized: "action.addVehicle"), systemImage: "plus")
                }
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
                            onAddEntry: {
                                selection = .vehicle(vehicle.id)
                                showAddEntry = true
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
                        Button {
                            editingVehicle = vehicle
                        } label: {
                            Label(String(localized: "action.edit"), systemImage: "pencil")
                        }
                    }
                }
                .onDelete(perform: deleteVehicles)
            }
        }
        .navigationTitle(String(localized: "app.title"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddVehicle = true } label: {
                    Label(String(localized: "action.addVehicle"), systemImage: "plus")
                }
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
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .vehicle:
            if let vehicle = selectedVehicle {
                VehicleDetailView(vehicle: vehicle, onAddEntry: { showAddEntry = true })
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddVehicle = true } label: {
                        Label(String(localized: "action.addVehicle"), systemImage: "plus")
                    }
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

