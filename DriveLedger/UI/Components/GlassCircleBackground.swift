import SwiftUI

extension View {
    func glassCircleBackground() -> some View {
        background(.regularMaterial, in: Circle())
            .overlay(
                Circle().strokeBorder(.separator, lineWidth: 0.5)
            )
            .contentShape(Circle())
    }
}
