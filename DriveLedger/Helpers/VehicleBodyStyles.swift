import Foundation

enum VehicleBodyStyleOption: String, CaseIterable, Identifiable {
    case sedan
    case hatchback
    case wagon
    case suv
    case crossover
    case coupe
    case convertible
    case pickup
    case van

    var id: String { rawValue }

    var title: String {
        let key = "vehicle.bodyStyle.\(rawValue)"
        return NSLocalizedString(key, comment: "Vehicle body style")
    }

    /// SF Symbol to represent the body style.
    var symbolName: String {
        switch self {
        case .sedan: return "car.fill"
        case .hatchback: return "car"
        case .wagon: return "car.2.fill"
        case .suv: return "suv.side.front.fill"
        case .crossover: return "suv.side.front"
        case .coupe: return "car.side.fill"
        case .convertible: return "car.side"
        case .pickup: return "truck.pickup.side.fill"
        case .van: return "bus.fill"
        }
    }
}
