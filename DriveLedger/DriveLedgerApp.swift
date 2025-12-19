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
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")

        let schema = Schema([
            Vehicle.self,
            LogEntry.self,
            MaintenanceInterval.self,
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        sharedModelContainer = try? ModelContainer(for: schema, configurations: [modelConfiguration])

        if isUITesting, let container = sharedModelContainer {
            let context = container.mainContext
            let existing = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
            if existing.isEmpty {
                let seededID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                context.insert(Vehicle(id: seededID, name: "Test Car"))
                try? context.save()
            }
        }
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
