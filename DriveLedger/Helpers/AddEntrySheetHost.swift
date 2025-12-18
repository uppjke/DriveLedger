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

    var body: some View {
        AddEntrySheet(vehicle: vehicle, existingEntries: vehicleEntries) { entry in
            // 1) создаём/вставляем запись (обычно родитель делает modelContext.insert(entry))
            onCreate(entry)

            // 2) пересчитываем расход для всех записей авто.
            //    @Query может обновиться не мгновенно, поэтому добавляем entry вручную и дедуплицируем по id.
            var merged = vehicleEntries
            merged.append(entry)

            var seen = Set<UUID>()
            merged = merged.filter { seen.insert($0.id).inserted }

            // детерминированный порядок для пересчёта: дата (возр.), затем пробег (возр.)
            merged.sort {
                if $0.date != $1.date { return $0.date < $1.date }
                let a = $0.odometerKm ?? Int.min
                let b = $1.odometerKm ?? Int.min
                return a < b
            }

            FuelConsumption.recalculateAll(existingEntries: merged)
            try? modelContext.save()
        }
    }
}
