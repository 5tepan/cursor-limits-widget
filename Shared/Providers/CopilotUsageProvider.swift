import Foundation
import Security

struct CopilotUsageProvider: UsageProvider {
    let id: ProviderID = .copilot

    func isAvailable() -> Bool {
        Self.loadGitHubToken() != nil
    }

    func refresh() async -> ProviderUsage {
        guard let token = Self.loadGitHubToken() else {
            return .authMissing(.copilot, message: L10n.t(
                "Выполните `gh auth login` или войдите в Copilot CLI.",
                "Run `gh auth login` or sign in to Copilot CLI."
            ))
        }

        do {
            let entitlement = try await Self.fetchEntitlement(token: token)
            let premium = entitlement.quota_snapshots?["premium_interactions"]
                ?? entitlement.quotaSnapshots?["premium_interactions"]

            var windows: [UsageWindow] = []
            if let premium {
                let used: Double?
                if let remaining = premium.remaining_percentage ?? premium.remainingPercentage {
                    // remaining is % left → used = 1 - remaining
                    used = UsageFraction.usedFromRemaining(remaining)
                } else if let entitlementRequests = premium.entitlement_requests ?? premium.entitlementRequests,
                          let usedRequests = premium.used_requests ?? premium.usedRequests,
                          entitlementRequests > 0
                {
                    used = min(Double(usedRequests) / Double(entitlementRequests), 1)
                } else {
                    used = nil
                }
                let reset = (premium.reset_date ?? premium.resetDate).flatMap {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                    return f.date(from: String($0.prefix(10)))
                        ?? ISO8601DateFormatter().date(from: $0)
                }
                windows.append(UsageWindow(label: "month", fraction: used, resetsAt: reset))
            }

            return ProviderUsage(
                providerID: .copilot,
                status: .ok,
                planName: entitlement.copilot_plan?.capitalized
                    ?? entitlement.access_type_sku
                    ?? "Copilot",
                email: nil,
                windows: windows,
                displayMessage: nil,
                errorMessage: windows.isEmpty
                    ? L10n.t("Квота premium не найдена", "Premium quota not found")
                    : nil,
                fetchedAt: Date(),
                tokenStats: nil,
                topModels: [],
                includedSpend: nil,
                totalSpend: nil,
                onDemandEnabled: false,
                onDemandUsedCents: nil
            )
        } catch let error as ProviderFetchError {
            return .failed(.copilot, userMessage: error.userMessage, technicalDetail: error.detail)
        } catch {
            return .failed(
                .copilot,
                userMessage: ProviderErrorCopy.humanize(error.localizedDescription)
                    ?? L10n.t("Ошибка обновления", "Refresh failed"),
                technicalDetail: error.localizedDescription
            )
        }
    }

    // MARK: - Token sources

    static func loadGitHubToken() -> String? {
        if let stored = readStoredToken(), !stored.isEmpty { return stored }
        if let gh = readGhCLIToken(), !gh.isEmpty { return gh }
        if let hosts = readGhHostsYML(), !hosts.isEmpty { return hosts }
        return nil
    }

    static func storeToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CursorLimits-GitHub",
            kSecAttrAccount as String: "copilot"
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func readStoredToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CursorLimits-GitHub",
            kSecAttrAccount as String: "copilot",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func readGhCLIToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "token"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let token = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (token?.isEmpty == false) ? token : nil
        } catch {
            return nil
        }
    }

    private static func readGhHostsYML() -> String? {
        let url = AppPaths.realHomeURL
            .appendingPathComponent(".config/gh/hosts.yml")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        // Very small YAML scrape for oauth_token under github.com
        var inGithub = false
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("github.com:") {
                inGithub = true
                continue
            }
            if inGithub, trimmed.hasPrefix("oauth_token:") {
                let value = trimmed
                    .replacingOccurrences(of: "oauth_token:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return value.isEmpty ? nil : value
            }
            if inGithub, !line.hasPrefix(" "), !line.hasPrefix("\t"), !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                inGithub = false
            }
        }
        return nil
    }

    // MARK: - API

    private struct Quota: Decodable {
        let entitlement_requests: Int?
        let used_requests: Int?
        let remaining_percentage: Double?
        let reset_date: String?
        // camelCase variants
        let entitlementRequests: Int?
        let usedRequests: Int?
        let remainingPercentage: Double?
        let resetDate: String?
    }

    private struct Entitlement: Decodable {
        let quota_snapshots: [String: Quota]?
        let quotaSnapshots: [String: Quota]?
        let copilot_plan: String?
        let access_type_sku: String?
    }

    private static func fetchEntitlement(token: String) async throws -> Entitlement {
        let urls = [
            URL(string: "https://api.github.com/copilot_internal/user")!,
            URL(string: "https://github.com/github-copilot/chat/entitlement")!
        ]
        var lastError: Error = URLError(.badServerResponse)
        for url in urls {
            var request = URLRequest(url: url)
            let auth = url.host?.contains("api.github.com") == true ? "Bearer \(token)" : "token \(token)"
            request.setValue(auth, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("CursorLimits/1.0", forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                guard (200..<300).contains(http.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    lastError = ProviderFetchError(
                        userMessage: ProviderErrorCopy.humanize("HTTP \(http.statusCode)")
                            ?? L10n.t("Ошибка обновления", "Refresh failed"),
                        detail: ProviderErrorCopy.detail(
                            from: http.statusCode,
                            host: url.host ?? "github.com",
                            body: body
                        )
                    )
                    continue
                }
                return try JSONDecoder().decode(Entitlement.self, from: data)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}

// MARK: - Device flow (optional connect from Settings)

enum GitHubDeviceFlow {
    /// Public VS Code GitHub OAuth client id (widely used by local tools).
    private static let clientID = "01ab8ac9400c4e429b23"
    private static let scope = "read:user"

    struct DeviceCode: Decodable {
        let device_code: String
        let user_code: String
        let verification_uri: String
        let expires_in: Int
        let interval: Int
    }

    struct TokenResponse: Decodable {
        let access_token: String?
        let error: String?
        let error_description: String?
    }

    static func requestDeviceCode() async throws -> DeviceCode {
        var request = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "client_id=\(clientID)&scope=\(scope)".data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(DeviceCode.self, from: data)
    }

    static func pollAccessToken(deviceCode: String, interval: Int) async throws -> String {
        let deadline = Date().addingTimeInterval(15 * 60)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(max(interval, 5)) * 1_000_000_000)
            var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody =
                "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
                .data(using: .utf8)
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            if let token = decoded.access_token, !token.isEmpty {
                CopilotUsageProvider.storeToken(token)
                return token
            }
            if decoded.error == "authorization_pending" || decoded.error == "slow_down" {
                continue
            }
            throw NSError(domain: "GitHubDeviceFlow", code: 1, userInfo: [
                NSLocalizedDescriptionKey: decoded.error_description ?? decoded.error ?? "OAuth failed"
            ])
        }
        throw URLError(.timedOut)
    }
}
