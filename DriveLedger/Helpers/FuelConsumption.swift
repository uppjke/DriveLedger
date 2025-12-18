//
//  FuelConsumption.swift
//  DriveLedger
//

import Foundation

enum FuelConsumption {

    enum Mode: String, CaseIterable, Identifiable {
        /// Точный режим: считаем только между двумя «полными баками», включая доливы между ними.
        case fullToFull
        /// Интуитивный режим по умолчанию: считаем между соседними заправками с пробегом.
        /// (литры берём из текущей заправки, дистанцию — между текущим и предыдущим пробегом)
        case perFillUp

        var id: String { rawValue }
        var title: String {
            switch self {
            case .perFillUp: return "По каждой заправке"
            case .fullToFull: return "Между полными баками"
            }
        }
    }

    /// Расход для "текущей" заправки (в форме Add/Edit), без мутаций модели.
    /// Считаем ТОЛЬКО если currentFillKind == .full.
    /// Литры берём как сумму всех заправок (full + partial) между предыдущим full и текущим full (включая текущую).
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
        guard let currentLitersDraft, currentLitersDraft > 0 else { return nil }

        // Берём все топливные записи с пробегом, чтобы корректно найти интервалы.
        // Сортируем стабильно: (date, odometer, id)
        let fuels = existingEntries
            .filter { $0.kind == .fuel }
            .filter { $0.odometerKm != nil }
            .sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                let ao = a.odometerKm ?? Int.min
                let bo = b.odometerKm ?? Int.min
                if ao != bo { return ao < bo }
                return a.id.uuidString < b.id.uuidString
            }

        // Находим предыдущую FULL-заправку строго до текущей точки (по пробегу в приоритете).
        // Если есть записи с пробегом < currentOdo — используем это как основной критерий.
        let candidatesPrev = fuels.filter { e in
            guard e.fuelFillKind == .full else { return false }
            guard let odo = e.odometerKm else { return false }

            // Если редактируем существующую запись — не считаем её самой "предыдущей"
            if let currentEntryID, e.id == currentEntryID { return false }

            // Ключевой критерий: предыдущий пробег
            if odo < currentOdo { return true }

            // Фоллбек по дате (на случай одинакового пробега/пустых данных)
            if odo == currentOdo {
                return e.date < currentDate
            }
            return false
        }

        guard let prevFull = candidatesPrev.max(by: { a, b in
            let ao = a.odometerKm ?? Int.min
            let bo = b.odometerKm ?? Int.min
            if ao != bo { return ao < bo }
            if a.date != b.date { return a.date < b.date }
            return a.id.uuidString < b.id.uuidString
        }) else {
            return nil
        }

        guard let prevOdo = prevFull.odometerKm, currentOdo > prevOdo else { return nil }

        // Суммируем литры между prevFull (НЕ включая prevFull) и текущим full (включая текущую).
        // В интервал попадают и "доливы".
        var litersSum: Double = 0

        for e in fuels {
            guard let odo = e.odometerKm else { continue }
            guard odo > prevOdo, odo <= currentOdo else { continue }

            // Текущую запись берём из draft-значений (она может ещё не быть сохранена/или редактируется)
            if let currentEntryID, e.id == currentEntryID {
                litersSum += currentLitersDraft
            } else {
                if let l = e.fuelLiters, l > 0 { litersSum += l }
            }
        }

        // Если добавляем новую запись (currentEntryID == nil), то в списке fuels её нет — добавим вручную.
        if currentEntryID == nil {
            litersSum += currentLitersDraft
        }

        let distance = Double(currentOdo - prevOdo)
        guard distance > 0 else { return nil }

        let cons = (litersSum / distance) * 100.0
        guard cons.isFinite, cons > 0 else { return nil }

        return cons
    }

    /// Пересчитывает и записывает расход в `fuelConsumptionLPer100km` для всех топливных записей.
    /// Важно: мутирует модели (подходит для Add/Edit/Delete обработчиков).
    static func recalculateAll(existingEntries: [LogEntry]) {
        // Стабильно сортируем
        let fuels = existingEntries
            .filter { $0.kind == .fuel }
            .sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                let ao = a.odometerKm ?? Int.min
                let bo = b.odometerKm ?? Int.min
                if ao != bo { return ao < bo }
                return a.id.uuidString < b.id.uuidString
            }

        // Сбрасываем всем
        for e in fuels {
            e.fuelConsumptionLPer100km = nil
        }

        // Для каждой FULL считаем расход от предыдущей FULL
        for e in fuels {
            guard e.fuelFillKind == .full else { continue }
            let cons = compute(
                currentEntryID: e.id,
                currentDate: e.date,
                currentOdo: e.odometerKm,
                currentLitersDraft: e.fuelLiters,
                currentFillKind: e.fuelFillKind,
                existingEntries: fuels
            )
            e.fuelConsumptionLPer100km = cons
        }
    }

    /// Серия точек расхода (для графика/аналитики), БЕЗ мутаций модели.
    /// Возвращает точки для FULL-заправок, где удалось посчитать расход.
    static func series(existingEntries: [LogEntry], mode: Mode = .perFillUp) -> [(date: Date, value: Double)] {
        let fuels = existingEntries
            .filter { $0.kind == .fuel }
            .sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                let ao = a.odometerKm ?? Int.min
                let bo = b.odometerKm ?? Int.min
                if ao != bo { return ao < bo }
                return a.id.uuidString < b.id.uuidString
            }

        var result: [(date: Date, value: Double)] = []

        switch mode {
        case .fullToFull:
            for e in fuels {
                guard e.fuelFillKind == .full else { continue }
                let cons = compute(
                    currentEntryID: e.id,
                    currentDate: e.date,
                    currentOdo: e.odometerKm,
                    currentLitersDraft: e.fuelLiters,
                    currentFillKind: e.fuelFillKind,
                    existingEntries: fuels
                )
                if let cons { result.append((date: e.date, value: cons)) }
            }

        case .perFillUp:
            // Берём только заправки с пробегом и литрами.
            let withOdo = fuels
                .filter { ($0.odometerKm ?? 0) > 0 }
                .filter { ($0.fuelLiters ?? 0) > 0 }

            guard withOdo.count >= 2 else { return [] }

            // Для каждой заправки (начиная со второй) считаем расход на интервал до неё,
            // используя литры текущей заправки и разницу пробега.
            for idx in 1..<withOdo.count {
                let prev = withOdo[idx - 1]
                let cur = withOdo[idx]
                guard let prevOdo = prev.odometerKm, let curOdo = cur.odometerKm else { continue }
                let distance = Double(curOdo - prevOdo)
                guard distance > 0 else { continue }
                let liters = cur.fuelLiters ?? 0
                guard liters > 0 else { continue }

                let cons = (liters / distance) * 100.0
                guard cons.isFinite, cons > 0 else { continue }
                result.append((date: cur.date, value: cons))
            }
        }

        // На всякий случай отсортируем по дате
        return result.sorted { $0.date < $1.date }
    }
}
