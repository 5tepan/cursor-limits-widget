import AppKit

/// Where the notch panel anchors, in global screen coordinates.
struct NotchMetrics: Equatable {
    var isPhysical: Bool
    var notchWidth: CGFloat
    var capHeight: CGFloat
    /// Clear space above the drawn card. On a Mac without a notch this is the
    /// menu bar, so the card sits under it instead of covering icons.
    var topClearance: CGFloat
    var notchCenterX: CGFloat
    var screenMaxY: CGFloat
    var visibleHeight: CGFloat
    var menuBarHeight: CGFloat

    static let fallback = NotchMetrics(
        isPhysical: false,
        notchWidth: 180,
        capHeight: 0,
        topClearance: 24,
        notchCenterX: 0,
        screenMaxY: 0,
        visibleHeight: 800,
        menuBarHeight: 24
    )

    /// Notched built-in display when one is attached, otherwise the main screen.
    static func screen() -> NSScreen? {
        let screens = NSScreen.screens.filter { !isMirroring($0) }
        if let notched = screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        return NSScreen.main ?? screens.first
    }

    static func measure(_ screen: NSScreen) -> NotchMetrics {
        let menuBarHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = max(120, screen.frame.width - left.width - right.width)
            return NotchMetrics(
                isPhysical: true,
                notchWidth: width,
                capHeight: screen.safeAreaInsets.top,
                topClearance: 0,
                notchCenterX: screen.frame.minX + left.width + width / 2,
                screenMaxY: screen.frame.maxY,
                visibleHeight: screen.visibleFrame.height,
                menuBarHeight: menuBarHeight
            )
        }

        return NotchMetrics(
            isPhysical: false,
            notchWidth: 180,
            capHeight: 0,
            topClearance: max(menuBarHeight, NSStatusBar.system.thickness),
            notchCenterX: screen.frame.midX,
            screenMaxY: screen.frame.maxY,
            visibleHeight: screen.visibleFrame.height,
            menuBarHeight: menuBarHeight
        )
    }

    private static func isMirroring(_ screen: NSScreen) -> Bool {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayMirrorsDisplay(number.uint32Value) != 0
    }
}

/// Connected services shown in the notch, primary first.
enum NotchContent {
    static func providers(
        snapshot: AppSnapshot,
        enabled: [ProviderID],
        primary: ProviderID
    ) -> [ProviderUsage] {
        let enabledSet = Set(enabled)
        let visible = snapshot.providers.filter { usage in
            guard enabledSet.contains(usage.providerID) else { return false }
            switch usage.status {
            case .ok, .error: return true
            case .authMissing, .missing: return false
            }
        }
        return visible.sorted { a, b in
            if a.providerID == primary { return true }
            if b.providerID == primary { return false }
            let ia = ProviderID.allCases.firstIndex(of: a.providerID) ?? 0
            let ib = ProviderID.allCases.firstIndex(of: b.providerID) ?? 0
            return ia < ib
        }
    }
}

/// Sizes and hit testing for the notch card. Pure so it can be tested without a window.
enum NotchLayout {
    static let chinHeight: CGFloat = 56
    static let shoulder: CGFloat = 14
    static let corner: CGFloat = 18
    static let shadowX: CGFloat = 28
    static let shadowBottom: CGFloat = 40
    static let expandedSlack: CGFloat = 16

    static func expandedWidth(notchWidth: CGFloat) -> CGFloat {
        max(400, notchWidth + 36)
    }

    static func blobSize(expanded: Bool, metrics: NotchMetrics, providerCount: Int) -> CGSize {
        let cap = metrics.capHeight
        if !expanded {
            // Nothing is drawn at rest. The hover target is the notch hole itself.
            return CGSize(width: metrics.notchWidth, height: max(cap, 1))
        }
        let cards = CGFloat(max(providerCount, 1))
        let ideal = cap + 78 + cards * 196
        let limit = min(640, max(280, metrics.visibleHeight - 32))
        let height = min(limit, max(cap + chinHeight + 168, ideal))
        return CGSize(width: expandedWidth(notchWidth: metrics.notchWidth), height: height)
    }

    static func windowFrame(metrics: NotchMetrics) -> CGRect {
        let blob = blobSize(expanded: true, metrics: metrics, providerCount: 8)
        let width = blob.width + shadowX * 2
        let height = metrics.topClearance + blob.height + shadowBottom
        return CGRect(
            x: metrics.notchCenterX - width / 2,
            y: metrics.screenMaxY - height,
            width: width,
            height: height
        )
    }

    /// Hover target. `sloppy` grows the open card so the pointer can travel
    /// to its edge without the panel snapping shut. The collapsed target
    /// stays tight so a pointer resting under the notch does not open it.
    static func pointerInside(
        metrics: NotchMetrics,
        expanded: Bool,
        providerCount: Int,
        point: CGPoint,
        sloppy: Bool
    ) -> Bool {
        if !expanded {
            if metrics.isPhysical {
                return notchHole(metrics).contains(point)
            }
            return topStrip(metrics).contains(point)
        }
        let size = blobSize(expanded: expanded, metrics: metrics, providerCount: providerCount)
        let outset: CGFloat = sloppy ? expandedSlack : 0
        if shapeContains(metrics: metrics, size: size, outset: outset, point: point) {
            return true
        }
        if metrics.isPhysical {
            let half = metrics.notchWidth / 2
            let onTopEdge = point.y >= metrics.screenMaxY && point.y <= metrics.screenMaxY + 2
            let inNotchX = abs(point.x - metrics.notchCenterX) <= half
            if onTopEdge && inNotchX { return true }
        } else if topStrip(metrics).contains(point) {
            return true
        } else if expanded, menuBarBridge(metrics).contains(point) {
            return true
        }
        return false
    }

    /// Visible card only — used to decide which clicks the panel keeps.
    static func interactive(
        metrics: NotchMetrics,
        expanded: Bool,
        providerCount: Int,
        point: CGPoint
    ) -> Bool {
        let size = blobSize(expanded: expanded, metrics: metrics, providerCount: providerCount)
        return shapeContains(metrics: metrics, size: size, outset: 0, point: point)
    }

    static func shapeContains(
        metrics: NotchMetrics,
        size: CGSize,
        outset: CGFloat,
        point: CGPoint
    ) -> Bool {
        let rect = blobRect(metrics: metrics, size: size, outset: outset)
        guard rect.width > 1, rect.height > 1 else { return false }
        let local = CGPoint(x: point.x - rect.minX, y: rect.maxY - point.y)
        let shape = NotchBlobShape(
            notchWidth: metrics.isPhysical ? metrics.notchWidth : size.width,
            capHeight: metrics.capHeight
        )
        return shape.path(in: CGRect(origin: .zero, size: rect.size)).contains(local)
    }

    static func blobRect(metrics: NotchMetrics, size: CGSize, outset: CGFloat) -> CGRect {
        var rect = CGRect(
            x: metrics.notchCenterX - size.width / 2,
            y: metrics.screenMaxY - metrics.topClearance - size.height,
            width: size.width,
            height: size.height
        )
        if outset > 0 {
            rect.origin.x -= outset
            rect.size.width += outset * 2
            rect.origin.y -= outset
            rect.size.height += outset
        }
        return rect
    }

    /// The physical cutout. A point below it, on the desktop, does not count.
    private static func notchHole(_ metrics: NotchMetrics) -> CGRect {
        CGRect(
            x: metrics.notchCenterX - metrics.notchWidth / 2,
            y: metrics.screenMaxY - max(metrics.capHeight, 1),
            width: metrics.notchWidth,
            height: max(metrics.capHeight, 1) + 2
        )
    }

    /// Thin target at the top centre of a display that has no physical notch.
    private static func topStrip(_ metrics: NotchMetrics) -> CGRect {
        CGRect(
            x: metrics.notchCenterX - 100,
            y: metrics.screenMaxY - 10,
            width: 200,
            height: 14
        )
    }

    /// While open, the pointer can cross the menu bar to reach the card.
    private static func menuBarBridge(_ metrics: NotchMetrics) -> CGRect {
        let width = expandedWidth(notchWidth: metrics.notchWidth)
        return CGRect(
            x: metrics.notchCenterX - width / 2,
            y: metrics.screenMaxY - metrics.topClearance,
            width: width,
            height: metrics.topClearance + 4
        )
    }
}
