import SwiftUI
import AppKit

/// Compact glyph for the menu bar: usage ring with a cursor tick.
/// Below 70% uses a template (system tint); higher usage draws an urgency color.
struct MenuBarGlyph: View {
    var fraction: Double?

    var body: some View {
        Image(nsImage: Self.makeImage(fraction: fraction))
            .renderingMode(Self.usesTemplate(fraction: fraction) ? .template : .original)
            .frame(width: 16, height: 16)
    }

    private static func usesTemplate(fraction: Double?) -> Bool {
        (fraction ?? 0) < 0.70
    }

    private static func strokeColor(fraction: Double?) -> NSColor {
        let progress = min(max(fraction ?? 0, 0), 1)
        switch progress {
        case ..<0.70:
            return NSColor.black
        case ..<0.90:
            return NSColor(red: 0.95, green: 0.62, blue: 0.12, alpha: 1)
        default:
            return NSColor(red: 0.90, green: 0.28, blue: 0.24, alpha: 1)
        }
    }

    private static func makeImage(fraction: Double?) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let color = strokeColor(fraction: fraction)
        let template = usesTemplate(fraction: fraction)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setShouldAntialias(true)

            let inset: CGFloat = 1.5
            let ring = rect.insetBy(dx: inset, dy: inset)
            let lineWidth: CGFloat = 1.75

            ctx.setStrokeColor(color.withAlphaComponent(template ? 0.28 : 0.35).cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.strokeEllipse(in: ring)

            let progress = min(max(fraction ?? 0, 0), 1)
            if progress > 0.001 {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let radius = (ring.width - lineWidth) / 2
                let start = -CGFloat.pi / 2
                let end = start + CGFloat(progress) * 2 * .pi
                ctx.setStrokeColor(color.cgColor)
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

            let tip = CGPoint(x: rect.midX + 1.6, y: rect.midY)
            let top = CGPoint(x: rect.midX - 1.8, y: rect.midY - 2.4)
            let bottom = CGPoint(x: rect.midX - 1.8, y: rect.midY + 2.4)
            ctx.setFillColor(color.cgColor)
            ctx.move(to: tip)
            ctx.addLine(to: top)
            ctx.addLine(to: bottom)
            ctx.closePath()
            ctx.fillPath()

            return true
        }
        image.isTemplate = template
        return image
    }
}
