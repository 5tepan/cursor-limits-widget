import Foundation
import Security
import CommonCrypto

/// Chromium / Electron `safeStorage` helpers (AES-128-CBC + Keychain password).
///
/// Used by Cursor when `cursor.storage.authTokenEncryptionAtRest` is on:
/// values look like `cursor-safe-storage:v1:` + base64(`v10`|`v11` ciphertext).
enum ChromiumSafeStorage {
    static let sealedPrefix = "cursor-safe-storage:v1:"

    /// Cursor Electron keychain service (exact string — do not derive from a display name).
    static let cursorKeychainService = "Cursor Safe Storage"
    /// Preferred account label Cursor writes today.
    static let cursorKeychainAccount = "Cursor Key"

    static func isSealed(_ value: String) -> Bool {
        value.hasPrefix(sealedPrefix)
    }

    /// Unwrap a DB cell: plaintext JWT passes through; sealed blobs need the Keychain key.
    static func unseal(_ value: String, key: Data?) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSealed(trimmed) else { return trimmed.isEmpty ? nil : trimmed }
        guard let key else { return nil }

        let encoded = String(trimmed.dropFirst(sealedPrefix.count))
        guard let encrypted = Data(base64Encoded: encoded),
              let plain = decrypt(encrypted, with: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !plain.isEmpty
        else { return nil }
        return plain
    }

    /// PBKDF2-SHA1 over the Keychain password → 16-byte AES key (Chromium defaults).
    static func deriveKey(fromPassword password: Data) -> Data? {
        var key = Data(count: 16)
        let salt = "saltysalt"
        let status = key.withUnsafeMutableBytes { out -> Int32 in
            password.withUnsafeBytes { secret in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    secret.baseAddress?.assumingMemoryBound(to: Int8.self),
                    secret.count,
                    salt,
                    salt.utf8.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                    1003,
                    out.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    16
                )
            }
        }
        return status == kCCSuccess ? key : nil
    }

    /// Decrypt Chromium `v10`/`v11` blob. Newer profiles may prepend a 32-byte host hash.
    static func decrypt(_ encrypted: Data, with key: Data) -> String? {
        guard encrypted.count > 3 else { return nil }

        let prefix = String(decoding: encrypted.prefix(3), as: UTF8.self)
        guard prefix == "v10" || prefix == "v11" else {
            return String(data: encrypted, encoding: .utf8)
        }

        let body = Data(encrypted.dropFirst(3))
        let iv = Data(repeating: UInt8(ascii: " "), count: kCCBlockSizeAES128)
        var out = Data(count: body.count + kCCBlockSizeAES128)
        var moved = 0

        let status: CCCryptorStatus = out.withUnsafeMutableBytes { output in
            body.withUnsafeBytes { input in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            kCCKeySizeAES128,
                            ivBytes.baseAddress,
                            input.baseAddress,
                            body.count,
                            output.baseAddress,
                            output.count,
                            &moved
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }

        let plain = out.prefix(moved)
        if let text = String(data: plain, encoding: .utf8), !text.isEmpty {
            return text
        }
        guard plain.count > 32,
              let text = String(data: plain.dropFirst(32), encoding: .utf8),
              !text.isEmpty
        else { return nil }
        return text
    }

    /// Encrypt helper for unit tests (mirrors Chromium cookie sealing).
    static func encryptForTests(_ plaintext: String, with key: Data) -> Data? {
        let data = Data(plaintext.utf8)
        let iv = Data(repeating: UInt8(ascii: " "), count: kCCBlockSizeAES128)
        var out = Data(count: data.count + kCCBlockSizeAES128)
        var moved = 0
        let status: CCCryptorStatus = out.withUnsafeMutableBytes { output in
            data.withUnsafeBytes { input in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            kCCKeySizeAES128,
                            ivBytes.baseAddress,
                            input.baseAddress,
                            data.count,
                            output.baseAddress,
                            output.count,
                            &moved
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return Data("v10".utf8) + out.prefix(moved)
    }
}

/// Cached read of Cursor's Electron safeStorage password from the login keychain.
///
/// Cached in-process so automatic refresh does not re-prompt every few minutes.
/// Call `allowAsking()` on manual refresh; `forget()` when a kept key stops opening rows.
enum CursorSafeStorageKeychain {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var kept: Data?
    nonisolated(unsafe) private static var refused = false

    static func key(read: () -> Data? = { readFromKeychain() }) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if let kept { return kept }
        guard !refused else { return nil }
        let value = read()
        kept = value
        refused = value == nil
        return value
    }

    static func allowAsking() {
        lock.lock()
        refused = false
        lock.unlock()
    }

    static func forget() {
        lock.lock()
        kept = nil
        lock.unlock()
    }

    static func resetForTests() {
        lock.lock()
        kept = nil
        refused = false
        lock.unlock()
    }

    private static func readFromKeychain() -> Data? {
        if let password = copyPassword(service: ChromiumSafeStorage.cursorKeychainService,
                                       account: ChromiumSafeStorage.cursorKeychainAccount),
           let key = ChromiumSafeStorage.deriveKey(fromPassword: password)
        {
            return key
        }
        // Older / alternate Cursor builds may omit or rename the account.
        if let password = copyPassword(service: ChromiumSafeStorage.cursorKeychainService, account: nil),
           let key = ChromiumSafeStorage.deriveKey(fromPassword: password)
        {
            return key
        }
        return nil
    }

    private static func copyPassword(service: String, account: String?) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              !data.isEmpty
        else { return nil }
        return data
    }
}
