import SwiftUI
import SwiftData

/// Нужен чтобы получать existingEntries через @Query, а не протаскивать allEntries в ContentView.
struct AddEntrySheetHost: View {
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle
    let onCreate: (LogEntry) -> Void
    let allowedKinds: [LogEntryKind]
    let initialKind: LogEntryKind?

    // В SwiftData #Predicate плохо дружит с relationship (`entry.vehicle`, `entry.vehicle?.id`, сравнение моделей),
    // из-за чего появляются ошибки макроса Predicate. Поэтому берем все записи и фильтруем в памяти.
    @Query(sort: \LogEntry.date, order: .reverse) private var allEntries: [LogEntry]

    private var vehicleEntries: [LogEntry] {
        allEntries.filter { $0.vehicle?.id == vehicle.id }
    }

    init(
        vehicle: Vehicle,
        allowedKinds: [LogEntryKind] = [.fuel, .service, .purchase, .tolls, .fines, .carwash, .parking],
        initialKind: LogEntryKind? = nil,
        onCreate: @escaping (LogEntry) -> Void
    ) {
        self.vehicle = vehicle
        self.allowedKinds = allowedKinds
        self.initialKind = initialKind
        self.onCreate = onCreate
    }

    private func handleCreate(_ entry: LogEntry) {
        // Вставку делает внешний onCreate (сейчас в ContentView это modelContext.insert(entry))
        onCreate(entry)

        // @Query обновляется не мгновенно — подстрахуемся снапшотом + добавлением entry вручную.
        var snapshot = vehicleEntries
        if !snapshot.contains(where: { $0.id == entry.id }) {
            snapshot.append(entry)
        }

        FuelConsumption.recalculateAll(existingEntries: snapshot)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            assertionFailure("Failed to save after creating entry: \(error)")
            #endif
            print("Failed to save after creating entry: \(error)")
        }

        // Mileage-based reminders are best-effort: re-evaluate after odometer-related changes.
        let currentKm = snapshot.compactMap { $0.odometerKm }.max() ?? vehicle.initialOdometerKm
        Task {
            await MaintenanceNotifications.syncAll(for: vehicle, currentKm: currentKm)
        }
    }

    var body: some View {
        AddEntrySheet(
            vehicle: vehicle,
            existingEntries: vehicleEntries,
            allowedKinds: allowedKinds,
            initialKind: initialKind,
            onCreate: handleCreate
        )
    }
}
