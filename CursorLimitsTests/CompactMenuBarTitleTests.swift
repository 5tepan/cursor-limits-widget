import XCTest
@testable import CursorLimits

final class CompactMenuBarTitleTests: XCTestCase {
    func testPercentOnlyWhenResetDisabled() {
        let title = Formatters.compactMenuBarTitle(
            fraction: 0.82,
            resetAt: Date().addingTimeInterval(4 * 24 * 3600),
            includeReset: false
        )
        XCTAssertEqual(title, "82%")
    }

    func testIncludesCompactDays() {
        let reset = Calendar.current.date(byAdding: .day, value: 4, to: Date())!
        let title = Formatters.compactMenuBarTitle(
            fraction: 0.82,
            resetAt: reset,
            includeReset: true
        )
        XCTAssertTrue(title.hasPrefix("82%"))
        XCTAssertTrue(title.contains("·"))
        XCTAssertTrue(title.contains("4"))
    }
}
