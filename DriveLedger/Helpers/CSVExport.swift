//
//  CSVExport.swift
//  DriveLedger
//
//  CSV export utilities for vehicles and log entries.
//

import Foundation

enum CSVExport {
    static func makeVehicleCSVExportURL(vehicleName: String, entries: [LogEntry]) -> URL? {
        let delimiter = ";"

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd HH:mm"

        func f2(_ v: Double?) -> String {
            guard let v else { return "" }
            return String(format: "%.2f", v)
        }

        func f1(_ v: Double?) -> String {
            guard let v else { return "" }
            return String(format: "%.1f", v)
        }

        func i(_ v: Int?) -> String {
            guard let v else { return "" }
            return String(v)
        }

        func esc(_ s: String?) -> String {
            guard var s, !s.isEmpty else { return "" }
            let needsQuotes = s.contains(delimiter) || s.contains("\"") || s.contains("\n") || s.contains("\r")
            s = s.replacingOccurrences(of: "\"", with: "\"\"")
            return needsQuotes ? "\"\(s)\"" : s
        }

        let fileName = sanitizeFileName(vehicleName.isEmpty ? "DriveLedger" : vehicleName) + ".csv"

        var lines: [String] = []
        lines.append([
            "vehicle",
            "date",
            "kind",
            "odometer_km",
            "cost_rub",
            "liters",
            "price_per_liter",
            "station",
            "consumption_l_100km",
            "service_title",
            "purchase_category",
            "vendor",
            "notes"
        ].joined(separator: delimiter))

        for e in entries {
            lines.append([
                esc(vehicleName),
                esc(df.string(from: e.date)),
                esc(e.kindRaw),
                i(e.odometerKm),
                f2(e.totalCost),
                f1(e.fuelLiters),
                f2(e.fuelPricePerLiter),
                esc(e.fuelStation),
                f1(e.fuelConsumptionLPer100km),
                esc(e.serviceTitle),
                esc(e.purchaseCategory),
                esc(e.purchaseVendor),
                esc(e.notes)
            ].joined(separator: delimiter))
        }

        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func sanitizeFileName(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "DriveLedger" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>")
        return base
            .components(separatedBy: invalid)
            .joined(separator: "-")
    }
}

