import SwiftUI
import XCTest
@testable import CursorLimits

final class NotchPanelTests: XCTestCase {
    func testNotchPanelDefaultsOff() {
        XCTAssertFalse(AppPreferences.default.notchPanelEnabled)
        let prefs = try? JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(prefs?.notchPanelEnabled, false)
    }

    func testShapeFillsNotchAndBodyButNotTheEars() {
        let shape = NotchBlobShape(notchWidth: 180, capHeight: 32)
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 400, height: 220))
        XCTAssertTrue(path.contains(CGPoint(x: 200, y: 10)))
        XCTAssertTrue(path.contains(CGPoint(x: 200, y: 120)))
        XCTAssertTrue(path.contains(CGPoint(x: 40, y: 140)))
        XCTAssertFalse(path.contains(CGPoint(x: 16, y: 8)))
        XCTAssertFalse(path.contains(CGPoint(x: 384, y: 8)))
        XCTAssertFalse(path.contains(CGPoint(x: 2, y: 216)))
    }

    func testPlainRoundedRectWithoutACap() {
        let shape = NotchBlobShape(notchWidth: 180, capHeight: 0)
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 220, height: 56))
        XCTAssertTrue(path.contains(CGPoint(x: 110, y: 28)))
        XCTAssertFalse(path.contains(CGPoint(x: 1, y: 1)))
    }

    func testConnectedProvidersSkipMissingAuthAndKeepPrimaryFirst() {
        var cursor = ProviderUsage.empty(.cursor)
        cursor.status = .ok
        cursor.windows = [UsageWindow(label: "Auto", fraction: 0.4, resetsAt: nil)]
        var claude = ProviderUsage.empty(.claude)
        claude.status = .authMissing
        var codex = ProviderUsage.empty(.codex)
        codex.status = .error
        codex.windows = [UsageWindow(label: "5h", fraction: 0.9, resetsAt: nil)]

        let snapshot = AppSnapshot(
            schemaVersion: 1,
            fetchedAt: Date(),
            providers: [cursor, claude, codex],
            enabledProviderIDs: [.cursor, .claude, .codex],
            primaryProviderID: .codex
        )
        let visible = NotchContent.providers(
            snapshot: snapshot,
            enabled: snapshot.enabledProviderIDs,
            primary: .codex
        )
        XCTAssertEqual(visible.map(\.providerID), [.codex, .cursor])
    }

    func testWindowSitsOnTheNotch() {
        let metrics = NotchMetrics(
            isPhysical: true,
            notchWidth: 180,
            capHeight: 32,
            topClearance: 0,
            notchCenterX: 800,
            screenMaxY: 1000,
            visibleHeight: 860,
            menuBarHeight: 32
        )
        let frame = NotchLayout.windowFrame(metrics: metrics)
        XCTAssertEqual(frame.midX, 800, accuracy: 0.1)
        XCTAssertEqual(frame.maxY, 1000, accuracy: 0.1)

        let top = CGPoint(x: 800, y: 1000)
        XCTAssertTrue(NotchLayout.pointerInside(
            metrics: metrics, expanded: false, providerCount: 2, point: top, sloppy: false
        ))
        let besideMenuBar = CGPoint(x: 800 - 400, y: 990)
        XCTAssertFalse(NotchLayout.pointerInside(
            metrics: metrics, expanded: false, providerCount: 2, point: besideMenuBar, sloppy: false
        ))
        let insideNotch = CGPoint(x: 800, y: 1000 - 16)
        XCTAssertTrue(NotchLayout.pointerInside(
            metrics: metrics, expanded: false, providerCount: 2, point: insideNotch, sloppy: false
        ))
        let belowNotch = CGPoint(x: 800, y: 1000 - 70)
        XCTAssertFalse(NotchLayout.pointerInside(
            metrics: metrics, expanded: false, providerCount: 2, point: belowNotch, sloppy: false
        ))
    }

    func testCollapsedCardStaysNarrowerThanTheOpenPanel() {
        let metrics = NotchMetrics(
            isPhysical: true,
            notchWidth: 200,
            capHeight: 32,
            topClearance: 0,
            notchCenterX: 0,
            screenMaxY: 0,
            visibleHeight: 900,
            menuBarHeight: 32
        )
        let closed = NotchLayout.blobSize(expanded: false, metrics: metrics, providerCount: 4)
        let open = NotchLayout.blobSize(expanded: true, metrics: metrics, providerCount: 4)
        XCTAssertEqual(closed.width, metrics.notchWidth, accuracy: 0.1)
        XCTAssertEqual(closed.height, metrics.capHeight, accuracy: 0.1)
        XCTAssertLessThan(closed.width, open.width)
        XCTAssertLessThan(closed.height, open.height)
    }
}
