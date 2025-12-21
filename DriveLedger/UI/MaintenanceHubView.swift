import SwiftUI

struct MaintenanceHubView: View {
    @Environment(\.dismiss) private var dismiss

    let showsCloseButton: Bool

    init(showsCloseButton: Bool = true) {
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                String(localized: "maintenance.redesign.title"),
                systemImage: "wrench.and.screwdriver",
                description: Text(String(localized: "maintenance.redesign.description"))
            )
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
