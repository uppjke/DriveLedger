import SwiftUI
import SwiftData

struct MaintenanceHubView: View {
    @Environment(\.dismiss) private var dismiss

    let showsCloseButton: Bool

    @Query(sort: \Vehicle.createdAt, order: .forward)
    private var vehicles: [Vehicle]

    init(showsCloseButton: Bool = true) {
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        NavigationStack {
            List {
                if vehicles.isEmpty {
                    ContentUnavailableView(
                        String(localized: "vehicles.empty.title"),
                        systemImage: "wrench.and.screwdriver",
                        description: Text(String(localized: "maintenance.hub.empty.description"))
                    )
                } else {
                    Section(String(localized: "maintenance.hub.section")) {
                        ForEach(vehicles) { vehicle in
                            NavigationLink {
                                List {
                                    MaintenanceIntervalsList(vehicle: vehicle)
                                }
                                .navigationTitle(vehicle.name)
                            } label: {
                                MaintenanceHubRow(vehicle: vehicle)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "tab.maintenance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.cancel")) { dismiss() }
                    }
                }
            }
        }
    }
}

private struct MaintenanceHubRow: View {
    let vehicle: Vehicle

    private var currentOdometerKm: Int? {
        vehicle.entries.compactMap { $0.odometerKm }.max()
    }

    private var counts: (overdue: Int, warning: Int) {
        var overdue = 0
        var warning = 0

        for interval in vehicle.maintenanceIntervals where interval.isEnabled {
            switch interval.status(currentKm: currentOdometerKm) {
            case .overdue:
                overdue += 1
            case .warning:
                warning += 1
            default:
                break
            }
        }

        return (overdue, warning)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.secondary)

            Text(vehicle.name)
                .font(.headline)

            Spacer()

            if counts.overdue > 0 {
                Label(String(counts.overdue), systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.red)
            } else if counts.warning > 0 {
                Label(String(counts.warning), systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.orange)
            }
        }
    }
}
