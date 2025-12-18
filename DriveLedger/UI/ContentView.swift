//
//  ContentView.swift
//  DriveLedger
//

import Foundation
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Vehicle.createdAt, order: .forward)
    private var vehicles: [Vehicle]

    @State private var selectedVehicleID: UUID?
    @State private var showAddVehicle = false
    @State private var showAddEntry = false
    @State private var editingVehicle: Vehicle?

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
            Section("Автомобили") {
                ForEach(vehicles) { vehicle in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.name)
                            .font(.headline)
                        if !vehicle.displaySubtitle.isEmpty {
                            Text(vehicle.displaySubtitle)
                                .font(.subheadline)
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
        .navigationTitle("DriveLedger")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddVehicle = true } label: {
                    Label("Добавить авто", systemImage: "plus")
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
                "Нет автомобилей",
                systemImage: "car",
                description: Text("Нажмите “+”, чтобы добавить первый автомобиль")
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddVehicle = true } label: {
                        Label("Добавить авто", systemImage: "plus")
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

