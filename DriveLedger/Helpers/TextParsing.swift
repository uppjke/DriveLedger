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

    // MARK: - Service title builder

    /// Builds a compact, human-friendly service title from checklist items.
    ///
    /// Goals:
    /// - remove empty items
    /// - recognize common maintenance tasks and normalize wording
    /// - dedupe
    /// - keep unknown items (lightly cleaned)
    ///
    /// Returns nil if nothing meaningful is left.
    static func buildServiceTitleFromChecklist(_ items: [String]) -> String? {
        let original = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !original.isEmpty else { return nil }

        let isRussian = original.contains { $0.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil }
        let strings = ServiceTitleStrings(isRussian: isRussian)

        func normalizeForMatch(_ s: String) -> String {
            let lower = s
                .lowercased()
                .replacingOccurrences(of: "ё", with: "е")

            var out = ""
            out.reserveCapacity(lower.count)

            var lastWasSpace = false
            for scalar in lower.unicodeScalars {
                if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.letters.contains(scalar) {
                    out.unicodeScalars.append(scalar)
                    lastWasSpace = false
                } else if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    if !lastWasSpace {
                        out.append(" ")
                        lastWasSpace = true
                    }
                } else {
                    // Treat punctuation as a space separator.
                    if !lastWasSpace {
                        out.append(" ")
                        lastWasSpace = true
                    }
                }
            }

            return out.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func extractFirstRegex(_ pattern: String, in s: String) -> String? {
            guard let r = s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
            return String(s[r])
        }

        func stripLeadingVerbs(_ s: String) -> String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return t }

            if isRussian {
                let patterns = [
                    "^(замена|смена|проверка|долив|долить|заменить|поменять|обслуживание)\\s+",
                    "^(то)\\s*\\d*\\s*[:\"\\-–—]\\s*"
                ]
                var cur = t
                for p in patterns {
                    cur = cur.replacingOccurrences(of: p, with: "", options: .regularExpression)
                }
                return cur.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                let patterns = [
                    "^(replace|change|check|top up|service)\\s+",
                    "^(maintenance)\\s*[:\"\\-–—]\\s*"
                ]
                var cur = t
                for p in patterns {
                    cur = cur.replacingOccurrences(of: p, with: "", options: .regularExpression)
                }
                return cur.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Detect common tasks.
        var engineOil = false
        var engineOilViscosity: String? = nil
        var oilFilter = false

        var airFilter = false
        var cabinFilter = false
        var fuelFilter = false

        var brakeFluid = false
        var brakeFluidDot: String? = nil
        var coolant = false
        var powerSteeringFluid = false
        var transmissionOil = false

        var sparkPlugs = false
        var brakePads = false
        var brakeDiscs = false
        var alignment = false
        var tireService = false
        var battery = false
        var wipers = false

        var matchedIndices = Set<Int>()

        for (idx, raw) in original.enumerated() {
            let n = normalizeForMatch(raw)
            guard !n.isEmpty else { continue }

            var matched = false

            if n.contains("масл") || n.contains("oil") {
                if n.contains("кпп") || n.contains("акпп") || n.contains("короб") || n.contains("transmission") || n.contains("gearbox") || n.contains("atf") || n.contains("dsg") {
                    transmissionOil = true
                    matched = true
                } else if (n.contains("масл") && n.contains("фильтр")) || n.contains("oil filter") {
                    oilFilter = true
                    matched = true
                } else {
                    engineOil = true
                    matched = true

                    if engineOilViscosity == nil {
                        // 0W-20, 5W30, 10w-40, 0w20
                        if let v = extractFirstRegex("\\b\\d{1,2}w-?\\d{1,2}\\b", in: raw) {
                            engineOilViscosity = v.uppercased().replacingOccurrences(of: "W", with: "W")
                        }
                    }
                }
            }

            if (n.contains("масл") && n.contains("фильтр")) || n.contains("oil filter") {
                oilFilter = true
                matched = true
            }
            if n.contains("воздуш") || n.contains("air filter") {
                airFilter = true
                matched = true
            }
            if n.contains("салон") || n.contains("cabin filter") || n.contains("pollen filter") {
                cabinFilter = true
                matched = true
            }
            if n.contains("топлив") || n.contains("fuel filter") {
                fuelFilter = true
                matched = true
            }

            if (n.contains("тормозн") && (n.contains("жидк") || n.contains("fluid"))) || n.contains("brake fluid") {
                brakeFluid = true
                matched = true
                if brakeFluidDot == nil {
                    brakeFluidDot = extractFirstRegex("\\bDOT\\s*\\d(\\.\\d)?\\b", in: raw)?.uppercased()
                }
            }
            if n.contains("антифриз") || n.contains("охлаж") || n.contains("coolant") {
                coolant = true
                matched = true
            }
            if n.contains("гур") || n.contains("power steering") {
                powerSteeringFluid = true
                matched = true
            }

            if n.contains("свеч") || n.contains("spark plug") {
                sparkPlugs = true
                matched = true
            }
            if n.contains("колодк") || n.contains("brake pad") || (n.contains("pads") && n.contains("brake")) {
                brakePads = true
                matched = true
            }
            if (n.contains("диск") && n.contains("торм")) || n.contains("brake disc") || n.contains("rotor") {
                brakeDiscs = true
                matched = true
            }
            if n.contains("развал") || n.contains("сход") || n.contains("alignment") {
                alignment = true
                matched = true
            }
            if n.contains("шином") || n.contains("баланс") || n.contains("переобув") || n.contains("шины") || n.contains("колес") || n.contains("tire") || n.contains("tyre") || n.contains("balance") {
                tireService = true
                matched = true
            }
            if n.contains("аккум") || n.contains("battery") {
                battery = true
                matched = true
            }
            if n.contains("дворник") || n.contains("щетк") || n.contains("wiper") {
                wipers = true
                matched = true
            }

            if matched {
                matchedIndices.insert(idx)
            }
        }

        // Build title parts in a stable, useful order.
        var parts: [String] = []
        parts.reserveCapacity(12)

        if engineOil && oilFilter {
            parts.append(strings.oilAndFilter(viscosity: engineOilViscosity))
        } else {
            if engineOil {
                parts.append(strings.engineOil(viscosity: engineOilViscosity))
            }
            if oilFilter {
                parts.append(strings.oilFilter)
            }
        }

        if airFilter { parts.append(strings.airFilter) }
        if cabinFilter { parts.append(strings.cabinFilter) }
        if fuelFilter { parts.append(strings.fuelFilter) }

        if brakeFluid { parts.append(strings.brakeFluid(dot: brakeFluidDot)) }
        if coolant { parts.append(strings.coolant) }
        if powerSteeringFluid { parts.append(strings.powerSteeringFluid) }
        if transmissionOil { parts.append(strings.transmissionOil) }

        if brakePads { parts.append(strings.brakePads) }
        if brakeDiscs { parts.append(strings.brakeDiscs) }
        if sparkPlugs { parts.append(strings.sparkPlugs) }

        if alignment { parts.append(strings.alignment) }
        if tireService { parts.append(strings.tireService) }
        if battery { parts.append(strings.battery) }
        if wipers { parts.append(strings.wipers) }

        // Append unknown items (cleaned), but dedup them.
        var seenUnknownKeys = Set<String>()
        for (idx, raw) in original.enumerated() {
            guard !matchedIndices.contains(idx) else { continue }
            let cleaned = stripLeadingVerbs(raw)
            guard let meaningful = cleanOptional(cleaned) else { continue }

            let key = normalizeForMatch(meaningful)
            guard !key.isEmpty else { continue }
            guard !seenUnknownKeys.contains(key) else { continue }
            seenUnknownKeys.insert(key)
            parts.append(meaningful)
        }

        // Final dedupe for known parts (safety).
        var seen = Set<String>()
        let deduped = parts.filter { part in
            let key = normalizeForMatch(part)
            guard !key.isEmpty else { return false }
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return cleanOptional(deduped.joined(separator: ", "))
    }

    private struct ServiceTitleStrings {
        let isRussian: Bool

        init(isRussian: Bool) {
            self.isRussian = isRussian
        }

        func engineOil(viscosity: String?) -> String {
            if let v = viscosity, !v.isEmpty {
                return isRussian ? "Масло \(v)" : "Oil \(v)"
            }
            return isRussian ? "Масло" : "Oil"
        }

        func oilAndFilter(viscosity: String?) -> String {
            if let v = viscosity, !v.isEmpty {
                return isRussian ? "Масло \(v) + фильтр" : "Oil \(v) + filter"
            }
            return isRussian ? "Масло + фильтр" : "Oil + filter"
        }

        var oilFilter: String { isRussian ? "Масляный фильтр" : "Oil filter" }
        var airFilter: String { isRussian ? "Воздушный фильтр" : "Air filter" }
        var cabinFilter: String { isRussian ? "Салонный фильтр" : "Cabin filter" }
        var fuelFilter: String { isRussian ? "Топливный фильтр" : "Fuel filter" }

        func brakeFluid(dot: String?) -> String {
            if let d = dot, !d.isEmpty {
                return isRussian ? "Тормозная жидкость \(d)" : "Brake fluid \(d)"
            }
            return isRussian ? "Тормозная жидкость" : "Brake fluid"
        }

        var coolant: String { isRussian ? "Охлаждающая жидкость" : "Coolant" }
        var powerSteeringFluid: String { isRussian ? "Жидкость ГУР" : "Power steering fluid" }
        var transmissionOil: String { isRussian ? "Масло КПП" : "Transmission oil" }

        var sparkPlugs: String { isRussian ? "Свечи" : "Spark plugs" }
        var brakePads: String { isRussian ? "Колодки" : "Brake pads" }
        var brakeDiscs: String { isRussian ? "Тормозные диски" : "Brake discs" }
        var alignment: String { isRussian ? "Развал-схождение" : "Alignment" }
        var tireService: String { isRussian ? "Шиномонтаж" : "Tire service" }
        var battery: String { isRussian ? "Аккумулятор" : "Battery" }
        var wipers: String { isRussian ? "Дворники" : "Wipers" }
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
