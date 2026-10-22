import Foundation
import Security
import SQLite3

struct CursorCredentials: Sendable {
    let accessToken: String
    let refreshToken: String?
    let membershipType: String?
    let email: String?
    let databaseURL: URL
}

/// Stores refreshed Cursor access tokens in our Keychain — never write Cursor's `state.vscdb`.
enum CursorTokenKeychain {
    private static let service = "CursorLimits-Cursor"
    private static let account = "accessToken"

    static func storeAccessToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func readAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else { return nil }
        return token
    }
}

enum CursorCredentialsLoader {
    private static let accessTokenKey = "cursorAuth/accessToken"
    private static let refreshTokenKey = "cursorAuth/refreshToken"
    private static let membershipTypeKey = "cursorAuth/stripeMembershipType"
    private static let emailKey = "cursorAuth/cachedEmail"

    static func defaultStateDatabaseURL(fileManager: FileManager = .default) -> URL {
        _ = fileManager
        return AppPaths.cursorStateDatabaseURL
    }

    static func load(fileManager: FileManager = .default) -> CursorCredentials? {
        let url = defaultStateDatabaseURL(fileManager: fileManager)
        let dbToken = readValue(key: accessTokenKey, at: url)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let keychainToken = CursorTokenKeychain.readAccessToken()

        // Prefer a non-expired Keychain token (from our refresh); fall back to Cursor DB.
        let accessToken: String?
        if let keychainToken, !isExpired(keychainToken) {
            accessToken = keychainToken
        } else if let dbToken, !dbToken.isEmpty {
            accessToken = dbToken
        } else {
            accessToken = keychainToken ?? dbToken
        }

        guard let accessToken, !accessToken.isEmpty else { return nil }

        return CursorCredentials(
            accessToken: accessToken,
            refreshToken: readValue(key: refreshTokenKey, at: url),
            membershipType: readValue(key: membershipTypeKey, at: url),
            email: readValue(key: emailKey, at: url),
            databaseURL: url
        )
    }

    static func jwtSubject(_ token: String) -> String? {
        guard let payload = jwtPayload(token) else { return nil }
        return payload["sub"] as? String
    }

    static func jwtExpiryDate(_ token: String) -> Date? {
        guard let payload = jwtPayload(token),
              let exp = payload["exp"] as? Double
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    static func isExpired(_ token: String, leeway: TimeInterval = 60, now: Date = Date()) -> Bool {
        guard let exp = jwtExpiryDate(token) else { return false }
        return exp <= now.addingTimeInterval(leeway)
    }

    /// Builds the WorkOS session cookie used by cursor.com dashboard APIs.
    static func workosSessionCookie(from credentials: CursorCredentials) -> String? {
        guard let sub = jwtSubject(credentials.accessToken), !sub.isEmpty else { return nil }
        // Cookie value is "<sub>::<accessToken>" (URL-encoded as %3A%3A in HTTP Cookie header).
        let raw = "\(sub)::\(credentials.accessToken)"
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: ":"))
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return "WorkosCursorSessionToken=\(encoded)"
    }

    private static func jwtPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - payload.count % 4) % 4
        payload += String(repeating: "=", count: padding)
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private static func readValue(key: String, at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else { return nil }
        defer { sqlite3_close(db) }

        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return nil }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0)
        else { return nil }

        return decodeBlobString(cString)
    }

    /// Cursor sometimes stores values as UTF-8, sometimes as UTF-16LE with NULs.
    private static func decodeBlobString(_ cString: UnsafePointer<UInt8>) -> String {
        let utf8 = String(cString: cString)
        if !utf8.contains("\0"), !utf8.isEmpty { return utf8 }

        let length = strlen(cString)
        let data = Data(bytes: cString, count: length)
        if let utf16 = String(data: data, encoding: .utf16LittleEndian)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !utf16.isEmpty
        {
            return utf16
        }
        return utf8.replacingOccurrences(of: "\0", with: "")
    }
}

enum CursorTokenRefresher {
    private static let refreshEndpoint = URL(string: "https://api2.cursor.sh/oauth/token")!
    private static let clientID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"

    static func refresh(_ credentials: CursorCredentials) async throws -> CursorCredentials {
        guard let refreshToken = credentials.refreshToken?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !refreshToken.isEmpty
        else {
            throw RefreshError.missingRefreshToken
        }

        var request = URLRequest(url: refreshEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RefreshError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              !accessToken.isEmpty
        else {
            throw RefreshError.invalidResponse
        }

        if json["shouldLogout"] as? Bool == true {
            throw RefreshError.shouldLogout
        }

        // Keep Cursor's DB read-only — store the refreshed token in our Keychain only.
        CursorTokenKeychain.storeAccessToken(accessToken)

        return CursorCredentials(
            accessToken: accessToken,
            refreshToken: credentials.refreshToken,
            membershipType: credentials.membershipType,
            email: credentials.email,
            databaseURL: credentials.databaseURL
        )
    }

    enum RefreshError: Error {
        case missingRefreshToken
        case shouldLogout
        case http(Int)
        case invalidResponse
    }
}
