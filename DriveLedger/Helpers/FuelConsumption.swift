import Foundation

enum FuelConsumption {

    // MARK: - Ordering helpers

    /// Stable ordering for fuel entries used in all consumption computations.
    /// Primary: date ascending
    /// Secondary: odometer ascending (nil treated as Int.min)
    /// Tertiary: UUID string (stable tie-breaker)
    private static func key(date: Date, odo: Int?, id: UUID) -> (Date, Int, String) {
        (date, odo ?? Int.min, id.uuidString)
    }

    private static func key(_ e: LogEntry) -> (Date, Int, String) {
        key(date: e.date, odo: e.odometerKm, id: e.id)
    }

    private static func lt(_ a: (Date, Int, String), _ b: (Date, Int, String)) -> Bool {
        if a.0 != b.0 { return a.0 < b.0 }
        if a.1 != b.1 { return a.1 < b.1 }
        return a.2 < b.2
    }

    private static func leq(_ a: (Date, Int, String), _ b: (Date, Int, String)) -> Bool {
        lt(a, b) || a == b
    }

    // MARK: - Draft compute

    /// Расход считаем только по "полным бакам".
    /// Литры берём как сумму всех fuel-записей между предыдущим full и текущим full (включая доливы),
    /// чтобы доливы не ломали математику.
    static func compute(
        currentEntryID: UUID?,
        currentDate: Date,
        currentOdo: Int?,
        currentLitersDraft: Double?,
        currentFillKind: FuelFillKind,
        existingEntries: [LogEntry]
    ) -> Double? {
        guard currentFillKind == .full else { return nil }
        guard let currentOdo, currentOdo > 0 else { return nil }

        // We sort by (date, odometer, id) to avoid edge-cases when timestamps match.
        let currentKey: (Date, Int, String) = (currentDate, currentOdo, "__DRAFT__")

        let fuels = existingEntries
            .filter { $0.kind == .fuel }
            .filter { $0.id != currentEntryID }
            .sorted { lt(key($0), key($1)) }

        // Previous FULL entry strictly before the current draft (by stable ordering)
        let prevFull = fuels
            .reversed()
            .first(where: { e in
                guard e.fuelFillKind == .full else { return false }
                guard let odo = e.odometerKm, odo > 0 else { return false }
                return lt(key(e), currentKey)
            })

        guard let prevFull,
              let prevOdo = prevFull.odometerKm,
              currentOdo > prevOdo
        else { return nil }

        let distance = Double(currentOdo - prevOdo)
        guard distance > 0 else { return nil }

        // Sum liters of all fuel entries strictly after prevFull and <= current draft (by ordering)
        let prevKey = key(prevFull)
        let litersBetween = fuels
            .filter { e in
                let k = key(e)
                return lt(prevKey, k) && leq(k, currentKey)
            }
            .compactMap { $0.fuelLiters }
            .reduce(0, +)

        let totalLiters = litersBetween + (currentLitersDraft ?? 0)
        guard totalLiters > 0 else { return nil }

        return (totalLiters / distance) * 100.0
    }

    // MARK: - Bulk recalculation

    /// Пересчитывает расход по всем топливным записям.
    /// Логика такая же, как в `compute`: расход считаем только для заправок типа `.full`.
    /// Для каждой `.full` записи берём дистанцию от предыдущей `.full` (с валидным одометром)
    /// и литры как сумму всех fuel-записей между ними + литры текущей записи.
    static func recalculateAll(existingEntries: [LogEntry]) {
        let fuels = existingEntries
            .filter { $0.kind == .fuel }
            .sorted { lt(key($0), key($1)) }

        // 1) Reset non-full entries
        for e in fuels where e.fuelFillKind != .full {
            e.fuelConsumptionLPer100km = nil
        }

        // 2) For each FULL entry compute from previous FULL (by stable ordering)
        for (idx, current) in fuels.enumerated() where current.fuelFillKind == .full {
            guard let currentOdo = current.odometerKm, currentOdo > 0 else {
                current.fuelConsumptionLPer100km = nil
                continue
            }
            guard let currentLiters = current.fuelLiters, currentLiters > 0 else {
                current.fuelConsumptionLPer100km = nil
                continue
            }

            // Find previous FULL entry before `idx` with valid odometer
            var prevIndex: Int?
            if idx > 0 {
                for j in stride(from: idx - 1, through: 0, by: -1) {
                    let e = fuels[j]
                    if e.fuelFillKind == .full, let odo = e.odometerKm, odo > 0 {
                        prevIndex = j
                        break
                    }
                }
            }

            guard let pIdx = prevIndex,
                  let prevOdo = fuels[pIdx].odometerKm,
                  currentOdo > prevOdo
            else {
                current.fuelConsumptionLPer100km = nil
                continue
            }

            let distance = Double(currentOdo - prevOdo)
            guard distance > 0 else {
                current.fuelConsumptionLPer100km = nil
                continue
            }

            // Sum liters of all entries between prev and current (excluding current), plus current liters.
            let litersBetween = fuels[(pIdx + 1)..<idx]
                .compactMap { $0.fuelLiters }
                .reduce(0, +)

            let totalLiters = litersBetween + currentLiters
            guard totalLiters > 0 else {
                current.fuelConsumptionLPer100km = nil
                continue
            }

            current.fuelConsumptionLPer100km = (totalLiters / distance) * 100.0
        }
    }
}
