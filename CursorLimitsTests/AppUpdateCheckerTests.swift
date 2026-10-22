import XCTest
@testable import CursorLimits

final class AppUpdateCheckerTests: XCTestCase {
    func testNormalizeStripsVPrefix() {
        XCTAssertEqual(AppUpdateChecker.normalizeVersion("v1.2.0"), "1.2.0")
        XCTAssertEqual(AppUpdateChecker.normalizeVersion("1.2.0"), "1.2.0")
    }

    func testNewerVersion() {
        XCTAssertTrue(AppUpdateChecker.isVersion("1.2.0", newerThan: "1.1.0"))
        XCTAssertTrue(AppUpdateChecker.isVersion("1.2.1", newerThan: "1.2.0"))
        XCTAssertTrue(AppUpdateChecker.isVersion("2.0.0", newerThan: "1.9.9"))
    }

    func testNotNewerWhenEqualOrOlder() {
        XCTAssertFalse(AppUpdateChecker.isVersion("1.2.0", newerThan: "1.2.0"))
        XCTAssertFalse(AppUpdateChecker.isVersion("1.1.9", newerThan: "1.2.0"))
        XCTAssertFalse(AppUpdateChecker.isVersion("v1.2.0", newerThan: "1.2.0"))
    }
}
