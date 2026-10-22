import XCTest
@testable import CursorLimits

final class BundleIdentityTests: XCTestCase {
    func testCurrentIds() {
        XCTAssertEqual(BundleIdentity.host, "com.5tepan.cursorlimits")
        XCTAssertEqual(BundleIdentity.widget, "com.5tepan.cursorlimits.widget")
        XCTAssertEqual(AppPaths.widgetBundleID, BundleIdentity.widget)
    }

    func testLegacyIdsDocumented() {
        XCTAssertEqual(BundleIdentity.legacyHost, "com.local.CursorLimits")
        XCTAssertEqual(BundleIdentity.legacyWidget, "com.local.CursorLimits.widget")
    }
}
