import XCTest
@testable import CursorLimits

final class AppSnapshotSchemaTests: XCTestCase {
    func testDecodesMissingSchemaVersionAsOne() throws {
        let json = """
        {
          "fetchedAt": "2026-10-21T12:00:00Z",
          "providers": [],
          "enabledProviderIDs": ["cursor"],
          "primaryProviderID": "cursor"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snap = try decoder.decode(AppSnapshot.self, from: json)
        XCTAssertEqual(snap.schemaVersion, 1)
        XCTAssertEqual(snap.primaryProviderID, .cursor)
    }

    func testEncodesSchemaVersion() throws {
        let snap = AppSnapshot.empty
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snap)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["schemaVersion"] as? Int, AppSnapshot.currentSchemaVersion)
    }
}
