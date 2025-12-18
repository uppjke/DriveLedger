import SwiftUI

enum VehicleColorOption: String, CaseIterable, Identifiable {
    case white
    case black
    case silver
    case gray
    case blue
    case red
    case green
    case yellow
    case brown
    case orange

    var id: String { rawValue }

    var title: String {
        let key = "vehicle.color.\(rawValue)"
        return NSLocalizedString(key, comment: "Vehicle color")
    }

    var swatch: Color {
        switch self {
        case .white: return .white
        case .black: return .black
        case .silver: return .gray.opacity(0.7)
        case .gray: return .gray
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .yellow: return .yellow
        case .brown: return .brown
        case .orange: return .orange
        }
    }
}
