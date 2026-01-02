import Foundation

enum WheelSpecsCatalog {
    static let tireSizeOtherToken = "__other__"

    // Curated common sizes (not exhaustive).
    static let commonTireSizes: [String] = [
        "175/65 R14",
        "185/60 R14",
        "185/65 R15",
        "195/55 R15",
        "195/60 R15",
        "195/65 R15",
        "205/55 R16",
        "205/60 R16",
        "215/55 R16",
        "215/60 R16",
        "225/45 R17",
        "225/50 R17",
        "225/55 R17",
        "235/45 R18",
        "235/50 R18",
        "245/45 R18",
        "255/40 R19"
    ]

    static let rimDiameterChoices: [Int] = Array(13...22)

    static let rimWidthChoices: [Double] = [
        4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0
    ]

    static let rimOffsetChoices: [Int] = [
        -10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60
    ]

    static func formatWidth(_ w: Double) -> String {
        let isInt = abs(w.rounded() - w) < 0.000_001
        return isInt ? String(Int(w.rounded())) : String(format: "%.1f", w)
    }

    static func normalizeWheelSetRimSpec(
        rimType: RimType?,
        diameter: Int?,
        width: Double?,
        offsetET: Int?
    ) -> String? {
        var parts: [String] = []
        if let t = rimType {
            parts.append(t.title)
        }
        if let d = diameter {
            parts.append("R\(d)")
        }
        if let w = width {
            parts.append("\(formatWidth(w))J")
        }
        if let et = offsetET {
            parts.append("ET\(et)")
        }
        let s = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }
}
