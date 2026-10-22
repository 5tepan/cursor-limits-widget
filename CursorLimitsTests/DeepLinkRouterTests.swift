import XCTest
@testable import CursorLimits

final class DeepLinkRouterTests: XCTestCase {
    func testRecognizesScheme() {
        XCTAssertEqual(DeepLinkRouter.scheme, "cursorlimits")
        XCTAssertEqual(DeepLinkRouter.Action(rawValue: "refresh"), .refresh)
        XCTAssertEqual(DeepLinkRouter.Action(rawValue: "settings"), .settings)
        XCTAssertNil(DeepLinkRouter.Action(rawValue: "unknown"))
    }
}
