//
//  DriveLedgerApp.swift
//  DriveLedger
//
//  Created by Vadim Gusev on 14.12.2025.
//

import SwiftUI
import SwiftData

@main
struct DriveLedgerApp: App {
    private let sharedModelContainer: ModelContainer?

    init() {
        let schema = Schema([
            Vehicle.self,
            LogEntry.self,
            MaintenanceInterval.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        sharedModelContainer = try? ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                ContentView()
                    .modelContainer(container)
            } else {
                ContentUnavailableView(
                    String(localized: "error.storage.title"),
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(String(localized: "error.storage.message"))
                )
            }
        }
    }
}
