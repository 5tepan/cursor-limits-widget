import XCTest
@testable import CursorLimits

final class UsageFractionTests: XCTestCase {
    func testNormalizeZeroToOne() {
        XCTAssertEqual(UsageFraction.normalize(0.42), 0.42, accuracy: 0.0001)
        XCTAssertEqual(UsageFraction.normalize(1.0), 1.0, accuracy: 0.0001)
    }

    func testNormalizePercentScale() {
        XCTAssertEqual(UsageFraction.normalize(42), 0.42, accuracy: 0.0001)
        XCTAssertEqual(UsageFraction.normalize(100), 1.0, accuracy: 0.0001)
    }

    func testNormalizeClamps() {
        XCTAssertEqual(UsageFraction.normalize(-1), 0, accuracy: 0.0001)
        XCTAssertEqual(UsageFraction.normalize(150), 1.0, accuracy: 0.0001)
    }

    func testUsedFromRemaining() {
        XCTAssertEqual(UsageFraction.usedFromRemaining(100), 0, accuracy: 0.0001)
        XCTAssertEqual(UsageFraction.usedFromRemaining(25), 0.75, accuracy: 0.0001)
        XCTAssertEqual(UsageFraction.usedFromRemaining(0.4), 0.6, accuracy: 0.0001)
    }
}
