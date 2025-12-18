import SwiftUI
import SwiftData

/// Нужен чтобы получать existingEntries через @Query, а не протаскивать allEntries в ContentView.
struct AddEntrySheetHost: View {
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle
    let onCreate: (LogEntry) -> Void

    // В SwiftData #Predicate плохо дружит с relationship (`entry.vehicle`, `entry.vehicle?.id`, сравнение моделей),
    // из-за чего появляются ошибки макроса Predicate. Поэтому берем все записи и фильтруем в памяти.
    @Query(sort: \LogEntry.date, order: .reverse) private var allEntries: [LogEntry]

    private var vehicleEntries: [LogEntry] {
        allEntries.filter { $0.vehicle?.id == vehicle.id }
    }

    init(vehicle: Vehicle, onCreate: @escaping (LogEntry) -> Void) {
        self.vehicle = vehicle
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
        try? modelContext.save()
    }

    var body: some View {
        AddEntrySheet(vehicle: vehicle, existingEntries: vehicleEntries, onCreate: handleCreate)
    }
}
