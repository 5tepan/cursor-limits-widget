import SwiftUI
import AppKit

/// Compact template glyph for the menu bar: a usage ring with a cursor tick.
struct MenuBarGlyph: View {
    var fraction: Double?

    var body: some View {
        Image(nsImage: Self.makeImage(fraction: fraction))
            .renderingMode(.template)
            .frame(width: 16, height: 16)
    }

    private static func makeImage(fraction: Double?) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setShouldAntialias(true)

            let inset: CGFloat = 1.5
            let ring = rect.insetBy(dx: inset, dy: inset)
            let lineWidth: CGFloat = 1.75

            // Track
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.28).cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.strokeEllipse(in: ring)

            // Progress arc
            let progress = min(max(fraction ?? 0, 0), 1)
            if progress > 0.001 {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let radius = (ring.width - lineWidth) / 2
                let start = -CGFloat.pi / 2
                let end = start + CGFloat(progress) * 2 * .pi
                ctx.setStrokeColor(NSColor.black.cgColor)
                ctx.setLineWidth(lineWidth)
                ctx.setLineCap(.round)
                ctx.addArc(
                    center: center,
                    radius: radius,
                    startAngle: start,
                    endAngle: end,
                    clockwise: false
                )
                ctx.strokePath()
            }

            // Inner cursor chevron (▶︎-like)
            let tip = CGPoint(x: rect.midX + 1.6, y: rect.midY)
            let top = CGPoint(x: rect.midX - 1.8, y: rect.midY - 2.4)
            let bottom = CGPoint(x: rect.midX - 1.8, y: rect.midY + 2.4)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.move(to: tip)
            ctx.addLine(to: top)
            ctx.addLine(to: bottom)
            ctx.closePath()
            ctx.fillPath()

            return true
        }
        image.isTemplate = true
        return image
    }
}
