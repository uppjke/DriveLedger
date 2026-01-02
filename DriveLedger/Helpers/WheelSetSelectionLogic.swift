import Foundation

enum WheelSetSelectionLogic {
    /// Returns true if an entry (identified by `entryID`) with `draftDate` would be the latest tire service
    /// entry compared to `existingEntries`.
    ///
    /// Ordering: date first, then `id.uuidString` to break ties deterministically.
    static func isLatestTireServiceEntry(
        existingEntries: [LogEntry],
        entryID: UUID,
        draftDate: Date
    ) -> Bool {
        let others = existingEntries.filter { $0.kind == .tireService && $0.id != entryID }
        guard let maxOther = others.max(by: { a, b in
            if a.date != b.date { return a.date < b.date }
            return a.id.uuidString < b.id.uuidString
        }) else {
            return true
        }

        if draftDate != maxOther.date { return draftDate > maxOther.date }
        return entryID.uuidString >= maxOther.id.uuidString
    }

    /// Applies a tire service wheel set result to the vehicle's current wheel set if this entry is the latest.
    ///
    /// If `wheelSetID` is nil ("no change"), this does nothing.
    static func updateVehicleCurrentWheelSetIfLatest(
        vehicle: Vehicle,
        existingEntries: [LogEntry],
        entryID: UUID,
        entryDate: Date,
        wheelSetID: UUID?
    ) {
        guard let wheelSetID else { return }
        guard isLatestTireServiceEntry(existingEntries: existingEntries, entryID: entryID, draftDate: entryDate) else { return }
        vehicle.currentWheelSetID = wheelSetID
    }
}
