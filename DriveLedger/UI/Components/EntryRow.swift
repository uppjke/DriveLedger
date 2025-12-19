//
//  EntryRow.swift
//  DriveLedger
//

import SwiftUI
import Foundation

struct EntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.kind.systemImage)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(entryTitle).font(.headline)

                HStack(spacing: 8) {
                    Text(entry.date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                    if let odo = entry.odometerKm {
                        Text("•").foregroundStyle(.secondary)
                        Text("\(odo) км")
                    }
                    if entry.kind == .fuel, let station = entry.fuelStation, !station.isEmpty {
                        Text("•").foregroundStyle(.secondary)
                        Text(station)
                    }
                    if entry.kind == .fuel, let c = entry.fuelConsumptionLPer100km {
                        Text("•").foregroundStyle(.secondary)
                        Text("\(DLFormatters.consumption(c)) л/100км")
                    }
                    if entry.kind == .tolls, let zone = entry.tollZone, !zone.isEmpty {
                        Text("•").foregroundStyle(.secondary)
                        Text(zone)
                    }
                    if entry.kind == .carwash, let location = entry.carwashLocation, !location.isEmpty {
                        Text("•").foregroundStyle(.secondary)
                        Text(location)
                    }
                    if entry.kind == .parking, let location = entry.parkingLocation, !location.isEmpty {
                        Text("•").foregroundStyle(.secondary)
                        Text(location)
                    }
                    if entry.kind == .fines, let violation = entry.finesViolationType, !violation.isEmpty {
                        Text("•").foregroundStyle(.secondary)
                        Text(violation)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let cost = entry.totalCost {
                Text(cost, format: .currency(code: DLFormatters.currencyCode))
                    .font(.headline)
            }
        }
    }

    private var entryTitle: String {
        switch entry.kind {
        case .fuel:
            if let liters = entry.fuelLiters {
                return "Заправка · \(DLFormatters.liters(liters)) л"
            }
            return "Заправка"
        case .service:
            return (entry.serviceTitle?.isEmpty == false) ? entry.serviceTitle! : "Обслуживание"
        case .purchase:
            return (entry.purchaseCategory?.isEmpty == false) ? entry.purchaseCategory! : "Покупка"
        case .tolls:
            return String(localized: "entry.kind.tolls")
        case .fines:
            return String(localized: "entry.kind.fines")
        case .carwash:
            return String(localized: "entry.kind.carwash")
        case .parking:
            return String(localized: "entry.kind.parking")
        case .odometer:
            return "Пробег"
        case .note:
            return "Заметка"
        }
    }
}

