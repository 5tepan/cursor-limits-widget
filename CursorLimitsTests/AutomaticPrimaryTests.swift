import XCTest
@testable import CursorLimits

final class AutomaticPrimaryTests: XCTestCase {
    func testPicksHighestUsageAmongOK() {
        let providers = [
            usage(.cursor, status: .ok, fraction: 0.2),
            usage(.claude, status: .ok, fraction: 0.8),
            usage(.codex, status: .authMissing, fraction: 0.99)
        ]
        let id = AppPreferencesStore.automaticPrimary(
            from: providers,
            enabled: [.cursor, .claude, .codex]
        )
        XCTAssertEqual(id, .claude)
    }

    func testFallsBackWhenNothingOK() {
        let providers = [
            usage(.cursor, status: .authMissing, fraction: nil),
            usage(.claude, status: .error, fraction: nil)
        ]
        let id = AppPreferencesStore.automaticPrimary(
            from: providers,
            enabled: [.cursor, .claude]
        )
        XCTAssertEqual(id, .cursor)
    }

    func testIgnoresDisabledEvenIfHigher() {
        let providers = [
            usage(.cursor, status: .ok, fraction: 0.1),
            usage(.claude, status: .ok, fraction: 0.9)
        ]
        let id = AppPreferencesStore.automaticPrimary(
            from: providers,
            enabled: [.cursor]
        )
        XCTAssertEqual(id, .cursor)
    }

    private func usage(_ id: ProviderID, status: SnapshotStatus, fraction: Double?) -> ProviderUsage {
        var snap = ProviderUsage.empty(id)
        snap.status = status
        if let fraction {
            snap.windows = [UsageWindow(label: "main", fraction: fraction, resetsAt: nil)]
        }
        snap.fetchedAt = Date()
        return snap
    }
}
