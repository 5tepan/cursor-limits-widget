import XCTest
@testable import CursorLimits

final class SecretRedactorTests: XCTestCase {
    func testRedactsBearerToken() {
        let input = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature"
        let out = SecretRedactor.redact(input)
        XCTAssertFalse(out.contains("eyJhbGci"))
        XCTAssertTrue(out.contains("[REDACTED]") || out.contains("[REDACTED_JWT]"))
    }

    func testRedactsGitHubPAT() {
        let input = "token ghp_abcdefghijklmnopqrstuvwxyz0123456789"
        let out = SecretRedactor.redact(input)
        XCTAssertFalse(out.contains("ghp_abcdefghijklmnopqrstuvwxyz0123456789"))
        XCTAssertTrue(out.contains("[REDACTED"))
    }

    func testRedactsJSONAccessToken() {
        let input = #"{"access_token":"super-secret-value-here","ok":true}"#
        let out = SecretRedactor.redact(input)
        XCTAssertFalse(out.contains("super-secret-value-here"))
    }

    func testTruncatesVeryLongPayload() {
        let input = String(repeating: "a", count: 5_000)
        let out = SecretRedactor.redact(input)
        XCTAssertTrue(out.count < 5_000)
        XCTAssertTrue(out.contains("truncated"))
    }
}
