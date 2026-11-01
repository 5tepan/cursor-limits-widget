import XCTest
@testable import CursorLimits

final class CodexUsageTests: XCTestCase {
    func testPercentValuesIncludingOneArePercentagePoints() throws {
        for (percent, expected) in [(0.0, 0.0), (1.0, 0.01), (4.0, 0.04), (100.0, 1.0)] {
            let data = Data("{\"used_percent\":\(percent)}".utf8)
            let window = try JSONDecoder().decode(CodexUsageProvider.Window.self, from: data)
            XCTAssertEqual(try XCTUnwrap(window.usedFraction), expected, accuracy: 0.00001)
        }
    }
}
