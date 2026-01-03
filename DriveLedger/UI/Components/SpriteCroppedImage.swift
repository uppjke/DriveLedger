import SwiftUI

struct SpriteCroppedImage: View {
    let image: Image
    /// Crop rectangle in normalized coordinates (0...1) relative to the full sprite.
    let crop: CGRect

    init(_ image: Image, crop: CGRect) {
        self.image = image
        self.crop = crop
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safeCrop = CGRect(
                x: crop.origin.x,
                y: crop.origin.y,
                width: max(crop.size.width, 0.000_001),
                height: max(crop.size.height, 0.000_001)
            )

            image
                .resizable()
                // Start by mapping the full sprite into the target frame,
                // then scale+offset so that `crop` fills the frame.
                .frame(width: size.width, height: size.height)
                .scaleEffect(
                    x: 1.0 / safeCrop.width,
                    y: 1.0 / safeCrop.height,
                    anchor: .topLeading
                )
                .offset(
                    x: -safeCrop.minX * size.width / safeCrop.width,
                    y: -safeCrop.minY * size.height / safeCrop.height
                )
        }
        .clipped()
    }
}

extension SpriteCroppedImage {
    /// Convenience for a 1-row sprite with N equal columns.
    static func column(_ index: Int, columns: Int) -> CGRect {
        guard columns > 0 else { return .zero }
        let w = 1.0 / CGFloat(columns)
        let x = CGFloat(index) * w
        return CGRect(x: x, y: 0, width: w, height: 1)
    }
}
