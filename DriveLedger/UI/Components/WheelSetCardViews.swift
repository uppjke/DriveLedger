import SwiftUI

struct GlassCardRow<Content: View>: View {
    var isActive: Bool = false
    var contentPadding: CGFloat = 12
    var cornerRadii: RectangleCornerRadii = RectangleCornerRadii(
        topLeading: 22,
        bottomLeading: 22,
        bottomTrailing: 22,
        topTrailing: 22
    )
    @ViewBuilder var content: () -> Content

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
    }

    var body: some View {
        content()
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(shape)
            .overlay {
                if isActive {
                    shape.strokeBorder(.tint, lineWidth: 1)
                }
            }
    }
}

struct WheelSetCardContent: View {
    let title: String
    let wheelSpecs: [WheelSpec]
    let summary: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !wheelSpecs.isEmpty {
                    WheelCirclesRow(specs: wheelSpecs)
                } else if !summary.isEmpty {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

private struct WheelCirclesRow: View {
    private let wheelCircleSize: CGFloat = 40
    private let wheelCircleSpacing: CGFloat = 10

    let specs: [WheelSpec]

    private var wheelSlotsWidth: CGFloat {
        wheelCircleSize * 4 + wheelCircleSpacing * 3
    }

    var body: some View {
        HStack(spacing: wheelCircleSpacing) {
            ForEach(0..<4, id: \.self) { idx in
                if idx < min(specs.count, 4) {
                    WheelCircle(spec: specs[idx])
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: wheelCircleSize, height: wheelCircleSize)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: wheelSlotsWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct WheelCircle: View {
    private let wheelCircleSize: CGFloat = 40

    let spec: WheelSpec

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))

            Text(spec.diameterLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: wheelCircleSize, height: wheelCircleSize)
    }
}
