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

    @Query(sort: \Vehicle.createdAt, order: .forward)
    private var vehicles: [Vehicle]

    @State private var selectedVehicleID: UUID?
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
        guard let id = selectedVehicleID else { return nil }
        return vehicles.first(where: { $0.id == id })
    }
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
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

                if selectedVehicleID == nil {
                    selectedVehicleID = vehicles.first?.id
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
                selectedVehicleID = vehicle.id
            }
        }
        .sheet(isPresented: $showAddEntry) {
            if let vehicle = selectedVehicle {
                AddEntrySheetHost(vehicle: vehicle) { entry in
                    modelContext.insert(entry)
                }
            } else {
                ContentUnavailableView("Сначала добавьте автомобиль", systemImage: "car")
                    .presentationDetents([.medium])
            }
        }
        .sheet(item: $editingVehicle) { v in
            EditVehicleSheet(vehicle: v)
        }
        .onAppear {
            if selectedVehicleID == nil {
                selectedVehicleID = vehicles.first?.id
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selectedVehicleID) {
            Section(String(localized: "vehicles.section.title")) {
                ForEach(vehicles) { vehicle in
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
                    .tag(vehicle.id as UUID?)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editingVehicle = vehicle
                        } label: {
                            Label("Править", systemImage: "pencil")
                        }
                        .tint(.blue)
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
        if let vehicle = selectedVehicle {
            VehicleDetailView(
                vehicle: vehicle,
                onAddEntry: { showAddEntry = true }
            )
        } else {
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

        if let current = selectedVehicleID,
           deleting.contains(where: { $0.id == current }) {
            selectedVehicleID = vehicles.first(where: { $0.id != current })?.id
        }
    }
}

