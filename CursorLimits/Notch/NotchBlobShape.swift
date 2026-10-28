import SwiftUI

/// Notch cap on top of a wider rounded card. With no cap, a plain rounded rect.
struct NotchBlobShape: Shape {
    var notchWidth: CGFloat
    var capHeight: CGFloat
    var shoulderRadius: CGFloat = NotchLayout.shoulder
    var cornerRadius: CGFloat = NotchLayout.corner

    func path(in rect: CGRect) -> Path {
        let cap = min(max(capHeight, 0), rect.height)
        let notch = min(max(notchWidth, 0), rect.width)
        let side = (rect.width - notch) / 2
        guard cap > 1, side > 6 else {
            let radius = min(cornerRadius, rect.height / 2, rect.width / 2)
            return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        }

        let shoulder = min(shoulderRadius, side * 0.55, cap * 0.8)
        let bodyHeight = rect.height - cap
        let corner = min(cornerRadius, max(4, side - shoulder - 1), max(4, bodyHeight / 2 - 1))
        let left = rect.midX - notch / 2
        let right = rect.midX + notch / 2
        let neck = rect.minY + cap

        var path = Path()
        path.move(to: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: right, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: right, y: neck),
            tangent2End: CGPoint(x: rect.maxX, y: neck),
            radius: shoulder
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: neck),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: neck),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: neck),
            tangent2End: CGPoint(x: left, y: neck),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: left, y: neck),
            tangent2End: CGPoint(x: left, y: rect.minY),
            radius: shoulder
        )
        path.closeSubpath()
        return path
    }
}
