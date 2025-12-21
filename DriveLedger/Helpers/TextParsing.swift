//
//  TextParsing.swift
//  DriveLedger
//
//

import Foundation

enum TextParsing {
    static func cleanOptional(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static func cleanRequired(_ s: String, fallback: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }

    static func parseIntOptional(_ s: String) -> Int? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Int(t)
    }

    static func parseDouble(_ s: String) -> Double? {
        let t = s
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(t)
    }

    // MARK: - VIN

    /// Normalizes a VIN string:
    /// - trims
    /// - removes spaces/dashes
    /// - uppercases
    ///
    /// Returns nil if the result is empty.
    static func normalizeVIN(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let noSeparators = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        let normalized = noSeparators.uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    // MARK: - Russian license plate

    /// Normalizes a Russian license plate string:
    /// - trims
    /// - removes spaces/dashes
    /// - uppercases
    /// - maps Latin look-alike letters to Cyrillic (A,B,E,K,M,H,O,P,C,T,Y,X -> А,В,Е,К,М,Н,О,Р,С,Т,У,Х)
    ///
    /// Returns nil if the result is empty.
    static func normalizeRussianLicensePlate(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let noSeparators = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        let upper = noSeparators.uppercased()
        let mapped = upper.map { ch -> Character in
            switch ch {
            case "A": return "А"
            case "B": return "В"
            case "E": return "Е"
            case "K": return "К"
            case "M": return "М"
            case "H": return "Н"
            case "O": return "О"
            case "P": return "Р"
            case "C": return "С"
            case "T": return "Т"
            case "Y": return "У"
            case "X": return "Х"
            default: return ch
            }
        }

        let normalized = String(mapped)
        return normalized.isEmpty ? nil : normalized
    }

    /// Validates a normalized RU private car plate.
    /// Accepts: Л999ЛЛ77 or Л999ЛЛ777 (Cyrillic letters from the allowed set + 3 digits + region 2-3 digits)
    static func isValidRussianPrivateCarPlate(_ normalized: String) -> Bool {
        // Allowed letters in Russian plates: АВЕКМНОРСТУХ
        let pattern = "^[АВЕКМНОРСТУХ][0-9]{3}[АВЕКМНОРСТУХ]{2}[0-9]{2,3}$"
        return normalized.range(of: pattern, options: .regularExpression) != nil
    }
}
