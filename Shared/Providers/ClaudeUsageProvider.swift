import Foundation
import Security

struct ClaudeUsageProvider: UsageProvider {
    let id: ProviderID = .claude

    func isAvailable() -> Bool {
        Self.loadAccessToken() != nil
    }

    func refresh() async -> ProviderUsage {
        guard let token = Self.loadAccessToken() else {
            return .authMissing(.claude, message: L10n.t(
                "Войдите в Claude Code (CLI) на этом Mac.",
                "Sign in to Claude Code (CLI) on this Mac."
            ))
        }

        do {
            let usage = try await Self.fetchUsage(token: token)
            var windows: [UsageWindow] = []
            if let five = usage.five_hour {
                windows.append(UsageWindow(
                    label: "5h",
                    fraction: five.utilization.map(Self.normalizeUtilization),
                    resetsAt: five.resets_at
                ))
            }
            if let week = usage.seven_day ?? usage.seven_day_oauth_apps {
                windows.append(UsageWindow(
                    label: "weekly",
                    fraction: week.utilization.map(Self.normalizeUtilization),
                    resetsAt: week.resets_at
                ))
            }
            return ProviderUsage(
                providerID: .claude,
                status: .ok,
                planName: "Claude",
                email: nil,
                windows: windows,
                displayMessage: nil,
                errorMessage: nil,
                fetchedAt: Date(),
                tokenStats: nil,
                topModels: [],
                includedSpend: nil,
                totalSpend: nil,
                onDemandEnabled: false,
                onDemandUsedCents: nil
            )
        } catch let error as ProviderFetchError {
            return .failed(.claude, userMessage: error.userMessage, technicalDetail: error.detail)
        } catch {
            return .failed(
                .claude,
                userMessage: ProviderErrorCopy.humanize(error.localizedDescription)
                    ?? L10n.t("Ошибка обновления", "Refresh failed"),
                technicalDetail: error.localizedDescription
            )
        }
    }

    private static func normalizeUtilization(_ value: Double) -> Double {
        let fraction = value > 1.5 ? value / 100.0 : value
        return min(max(fraction, 0), 1)
    }

    // MARK: - Credentials

    private static func loadAccessToken() -> String? {
        if let file = readCredentialsFile() { return file }
        return readKeychainToken()
    }

    private static func readCredentialsFile() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".claude/.credentials.json"),
            home.appendingPathComponent(".config/claude/.credentials.json")
        ]
        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let token = json["accessToken"] as? String, !token.isEmpty { return token }
            if let token = json["claudeAiOauth"] as? [String: Any],
               let access = token["accessToken"] as? String, !access.isEmpty
            {
                return access
            }
            if let nested = json["oauth"] as? [String: Any],
               let access = nested["accessToken"] as? String, !access.isEmpty
            {
                return access
            }
        }
        return nil
    }

    private static func readKeychainToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let raw = String(data: data, encoding: .utf8),
              let json = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        else { return nil }

        if let token = json["accessToken"] as? String, !token.isEmpty { return token }
        if let oauth = json["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String, !token.isEmpty
        {
            return token
        }
        return nil
    }

    // MARK: - API

    private struct Bucket: Decodable {
        let utilization: Double?
        let resets_at: Date?

        enum CodingKeys: String, CodingKey { case utilization, resets_at }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let d = try? c.decodeIfPresent(Double.self, forKey: .utilization) {
                utilization = d
            } else if let i = try? c.decodeIfPresent(Int.self, forKey: .utilization) {
                utilization = Double(i)
            } else {
                utilization = nil
            }
            if let date = try? c.decodeIfPresent(Date.self, forKey: .resets_at) {
                resets_at = date
            } else if let string = try? c.decodeIfPresent(String.self, forKey: .resets_at) {
                resets_at = ISO8601DateFormatter().date(from: string)
                    ?? {
                        let f = ISO8601DateFormatter()
                        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        return f.date(from: string)
                    }()
            } else {
                resets_at = nil
            }
        }
    }

    private struct Response: Decodable {
        let five_hour: Bucket?
        let seven_day: Bucket?
        let seven_day_oauth_apps: Bucket?
    }

    private static func fetchUsage(token: String) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderFetchError(
                userMessage: ProviderErrorCopy.humanize("HTTP \(http.statusCode)")
                    ?? L10n.t("Ошибка обновления", "Refresh failed"),
                detail: ProviderErrorCopy.detail(from: http.statusCode, host: "api.anthropic.com", body: body)
            )
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }
}
