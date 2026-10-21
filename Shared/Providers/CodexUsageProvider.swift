import Foundation

struct CodexUsageProvider: UsageProvider {
    let id: ProviderID = .codex

    func isAvailable() -> Bool {
        Self.loadAccessToken() != nil
    }

    func refresh() async -> ProviderUsage {
        guard let token = Self.loadAccessToken() else {
            return .authMissing(.codex, message: L10n.t(
                "Войдите в Codex CLI на этом Mac.",
                "Sign in to Codex CLI on this Mac."
            ))
        }

        do {
            let accountID = Self.loadAccountID()
            let usage = try await Self.fetchUsage(token: token, accountID: accountID)
            var windows: [UsageWindow] = []
            if let five = usage.rate_limit?.five_hour ?? usage.five_hour {
                windows.append(UsageWindow(
                    label: "5h",
                    fraction: five.usedFraction,
                    resetsAt: five.resetDate
                ))
            }
            if let week = usage.rate_limit?.weekly ?? usage.weekly {
                windows.append(UsageWindow(
                    label: "weekly",
                    fraction: week.usedFraction,
                    resetsAt: week.resetDate
                ))
            }
            return ProviderUsage(
                providerID: .codex,
                status: .ok,
                planName: usage.plan_type?.capitalized ?? "Codex",
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
            return .failed(.codex, userMessage: error.userMessage, technicalDetail: error.detail)
        } catch {
            return .failed(
                .codex,
                userMessage: ProviderErrorCopy.humanize(error.localizedDescription)
                    ?? L10n.t("Ошибка обновления", "Refresh failed"),
                technicalDetail: error.localizedDescription
            )
        }
    }

    private static func authFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
    }

    private static func loadAuthJSON() -> [String: Any]? {
        guard let data = try? Data(contentsOf: authFileURL()),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private static func loadAccessToken() -> String? {
        guard let json = loadAuthJSON() else { return nil }
        if let token = json["access_token"] as? String, !token.isEmpty { return token }
        if let tokens = json["tokens"] as? [String: Any],
           let token = tokens["access_token"] as? String, !token.isEmpty
        {
            return token
        }
        return nil
    }

    private static func loadAccountID() -> String? {
        guard let json = loadAuthJSON() else { return nil }
        if let id = json["account_id"] as? String { return id }
        if let tokens = json["tokens"] as? [String: Any],
           let id = tokens["account_id"] as? String
        {
            return id
        }
        return nil
    }

    private struct Window: Decodable {
        let used_percent: Double?
        let limit_window_seconds: Double?
        let reset_at: Double?
        let reset_after_seconds: Double?

        var usedFraction: Double? {
            guard let used_percent else { return nil }
            // API may return 0...100 or 0...1
            return used_percent > 1.5 ? used_percent / 100.0 : used_percent
        }

        var resetDate: Date? {
            if let reset_at {
                let seconds = reset_at > 10_000_000_000 ? reset_at / 1000.0 : reset_at
                return Date(timeIntervalSince1970: seconds)
            }
            if let reset_after_seconds {
                return Date().addingTimeInterval(reset_after_seconds)
            }
            return nil
        }
    }

    private struct RateLimit: Decodable {
        let five_hour: Window?
        let weekly: Window?

        enum CodingKeys: String, CodingKey {
            case five_hour, weekly, primary_window, secondary_window
            case fiveHour = "fiveHour"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            five_hour = try c.decodeIfPresent(Window.self, forKey: .five_hour)
                ?? c.decodeIfPresent(Window.self, forKey: .fiveHour)
                ?? c.decodeIfPresent(Window.self, forKey: .primary_window)
            weekly = try c.decodeIfPresent(Window.self, forKey: .weekly)
                ?? c.decodeIfPresent(Window.self, forKey: .secondary_window)
        }
    }

    private struct Response: Decodable {
        let plan_type: String?
        let rate_limit: RateLimit?
        // Flat fallbacks
        let five_hour: Window?
        let weekly: Window?
    }

    private static func fetchUsage(token: String, accountID: String?) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderFetchError(
                userMessage: ProviderErrorCopy.humanize("HTTP \(http.statusCode)")
                    ?? L10n.t("Ошибка обновления", "Refresh failed"),
                detail: ProviderErrorCopy.detail(from: http.statusCode, host: "chatgpt.com", body: body)
            )
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
