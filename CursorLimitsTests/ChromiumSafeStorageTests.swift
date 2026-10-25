import XCTest
@testable import CursorLimits

final class ChromiumSafeStorageTests: XCTestCase {
    func testDeriveKeyIsDeterministic16Bytes() {
        let password = Data("peanuts".utf8)
        let a = ChromiumSafeStorage.deriveKey(fromPassword: password)
        let b = ChromiumSafeStorage.deriveKey(fromPassword: password)
        XCTAssertEqual(a?.count, 16)
        XCTAssertEqual(a, b)
    }

    func testEncryptDecryptRoundTrip() throws {
        let password = Data("test-password".utf8)
        let key = try XCTUnwrap(ChromiumSafeStorage.deriveKey(fromPassword: password))
        let plain = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.sig"
        let encrypted = try XCTUnwrap(ChromiumSafeStorage.encryptForTests(plain, with: key))
        XCTAssertEqual(String(decoding: encrypted.prefix(3), as: UTF8.self), "v10")
        XCTAssertEqual(ChromiumSafeStorage.decrypt(encrypted, with: key), plain)
    }

    func testUnsealPlaintextPassthrough() {
        let jwt = "aaa.bbb.ccc"
        XCTAssertEqual(ChromiumSafeStorage.unseal(jwt, key: nil), jwt)
        XCTAssertFalse(ChromiumSafeStorage.isSealed(jwt))
    }

    func testUnsealSealedRequiresKey() throws {
        let password = Data("cursor-key".utf8)
        let key = try XCTUnwrap(ChromiumSafeStorage.deriveKey(fromPassword: password))
        let plain = "access-token-value"
        let blob = try XCTUnwrap(ChromiumSafeStorage.encryptForTests(plain, with: key))
        let sealed = ChromiumSafeStorage.sealedPrefix + blob.base64EncodedString()

        XCTAssertTrue(ChromiumSafeStorage.isSealed(sealed))
        XCTAssertNil(ChromiumSafeStorage.unseal(sealed, key: nil))
        XCTAssertEqual(ChromiumSafeStorage.unseal(sealed, key: key), plain)
    }

    func testIsExpiredTreatsNonJWTAsExpired() {
        XCTAssertTrue(CursorCredentialsLoader.isExpired("cursor-safe-storage:v1:abc"))
        XCTAssertTrue(CursorCredentialsLoader.isExpired("not-a-jwt"))
        XCTAssertFalse(CursorCredentialsLoader.looksLikeJWT("cursor-safe-storage:v1:abc"))
    }

    func testLooksLikeJWT() {
        XCTAssertTrue(CursorCredentialsLoader.looksLikeJWT("a.b.c"))
        XCTAssertFalse(CursorCredentialsLoader.looksLikeJWT("a.b"))
        XCTAssertFalse(CursorCredentialsLoader.looksLikeJWT(""))
    }
}
