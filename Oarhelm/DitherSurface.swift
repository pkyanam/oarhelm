import SwiftUI

/// A static ordered-dither field. Dots are batched into a single Canvas path;
/// the adaptive cell size bounds the amount of work on unusually large surfaces.
struct DitherSurface: View {
    enum Placement { case backdrop, edge }
    var placement: Placement = .backdrop
    var color: Color = VikingTheme.accent

    private let bayer: [Int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let cell = max(4, sqrt(size.width * size.height / 16000))
            let columns = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            var dots = Path()
            for y in 0..<rows {
                for x in 0..<columns {
                    let px = (CGFloat(x) + 0.5) * cell
                    let py = (CGFloat(y) + 0.5) * cell
                    let tone: CGFloat
                    switch placement {
                    case .backdrop:
                        let dx = px / max(size.width, 1)
                        let dy = py / max(size.height, 1)
                        let distance = sqrt(dx * dx + dy * dy)
                        tone = max(0, 0.52 * (1 - distance / 0.72))
                    case .edge:
                        let dx = px / max(size.width, 1)
                        let dy = py / max(size.height, 1)
                        tone = max(0, 0.38 * (1 - dx / 0.55) * (1 - dy / 0.22))
                    }
                    let threshold = (CGFloat(bayer[(y % 4) * 4 + x % 4]) + 0.5) / 16
                    if tone > threshold {
                        dots.addRect(CGRect(x: px, y: py, width: cell * 0.42, height: cell * 0.42))
                    }
                }
            }
            context.fill(dots, with: .color(color.opacity(placement == .backdrop ? 0.055 : 0.08)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
