import SwiftUI

/// The classic transparency checkerboard, drawn behind cutout previews so the
/// user can see exactly which pixels became transparent.
struct Checkerboard: View {
    var squareSize: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let columns = Int((size.width / squareSize).rounded(.up))
            let rows = Int((size.height / squareSize).rounded(.up))
            let light = Color(white: 0.92)
            let dark = Color(white: 0.82)

            for row in 0..<rows {
                for column in 0..<columns {
                    let isDark = (row + column).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(column) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(isDark ? dark : light))
                }
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}
