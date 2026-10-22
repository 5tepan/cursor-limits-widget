import Foundation

struct OllamaCloudUsageProvider: UsageProvider {
    let id: ProviderID = .ollamaCloud

    private static let aliases = [
        "ollama-cloud",
        "ollama_cloud",
        "ollamacloud",
        "ollama"
    ]

    func isAvailable() -> Bool {
        Self.loadAPIKey() != nil
    }

    func refresh() async -> ProviderUsage {
        guard let key = Self.loadAPIKey() else {
            return .authMissing(.ollamaCloud, message: L10n.t(
                "Добавьте Ollama Cloud в OpenCode или задайте OLLAMA_API_KEY.",
                "Add Ollama Cloud in OpenCode or set OLLAMA_API_KEY."
            ))
        }

        do {
            let balance = try await Self.fetchBalance(apiKey: key)
            var windows: [UsageWindow] = []
            var planName = "Ollama Cloud"

            if let allowance = balance.included?.allowance_usd,
               let remaining = balance.included?.balance_usd,
               allowance > 0
            {
                let usedFraction = min(max(1.0 - (remaining / allowance), 0), 1)
                windows.append(UsageWindow(
                    label: "month",
                    fraction: usedFraction,
                    resetsAt: balance.included?.period?.untilDate
                ))
                planName = String(format: "$%.0f incl.", allowance)
            } else if let session = balance.included?.session {
                // Legacy: remaining_percent is % left
                let rem = session.remaining_percent ?? 100
                windows.append(UsageWindow(
                    label: "session",
                    fraction: UsageFraction.usedFromRemaining(rem),
                    resetsAt: session.resetsDate
                ))
                if let weekly = balance.included?.weekly {
                    let wRem = weekly.remaining_percent ?? 100
                    windows.append(UsageWindow(
                        label: "weekly",
                        fraction: UsageFraction.usedFromRemaining(wRem),
                        resetsAt: weekly.resetsDate
                    ))
                }
            }

            if let purchased = balance.purchased?.balance_usd, purchased > 0, windows.isEmpty {
                // Credits-only view when included structure is unknown
                windows.append(UsageWindow(label: "credits", fraction: nil, resetsAt: nil))
                planName = String(format: "$%.2f", purchased)
            }

            let includedSpend: Double? = {
                guard let allowance = balance.included?.allowance_usd,
                      let remaining = balance.included?.balance_usd
                else { return nil }
                return max(allowance - remaining, 0)
            }()

            return ProviderUsage(
                providerID: .ollamaCloud,
                status: .ok,
                planName: planName,
                email: nil,
                windows: windows,
                displayMessage: nil,
                errorMessage: nil,
                fetchedAt: Date(),
                tokenStats: nil,
                topModels: [],
                includedSpend: includedSpend,
                totalSpend: includedSpend,
                onDemandEnabled: (balance.purchased?.balance_usd ?? 0) > 0,
                onDemandUsedCents: nil
            )
        } catch let error as ProviderFetchError {
            return .failed(.ollamaCloud, userMessage: error.userMessage, technicalDetail: error.detail)
        } catch {
            return .failed(
                .ollamaCloud,
                userMessage: L10n.t("Ошибка обновления", "Refresh failed"),
                technicalDetail: error.localizedDescription
            )
        }
    }

    private static func loadAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["OLLAMA_API_KEY"], !env.isEmpty {
            return env
        }
        return OpenCodeAuthStore.apiKey(matching: aliases)
    }

    private struct Period: Decodable {
        let from: String?
        let until: String?

        var untilDate: Date? { Self.parse(until) }
        var fromDate: Date? { Self.parse(from) }

        private static func parse(_ value: String?) -> Date? {
            guard let value else { return nil }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: value) { return d }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: value)
        }
    }

    private struct LegacyLimit: Decodable {
        let remaining_percent: Double?
        let resets_at: String?

        var resetsDate: Date? {
            guard let resets_at else { return nil }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: resets_at) { return d }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: resets_at)
        }
    }

    private struct Included: Decodable {
        let balance_usd: Double?
        let allowance_usd: Double?
        let period: Period?
        let session: LegacyLimit?
        let weekly: LegacyLimit?
    }

    private struct Purchased: Decodable {
        let balance_usd: Double?
    }

    private struct BalanceResponse: Decodable {
        let included: Included?
        let purchased: Purchased?
    }

    private static func fetchBalance(apiKey: String) async throws -> BalanceResponse {
        let url = URL(string: "https://ollama.com/api/balance")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CursorLimits/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderFetchError(
                userMessage: L10n.t("Ошибка обновления", "Refresh failed"),
                detail: "Invalid response from ollama.com"
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderFetchError(
                userMessage: ProviderErrorCopy.humanize("HTTP \(http.statusCode): \(body)")
                    ?? L10n.t("Ошибка обновления", "Refresh failed"),
                detail: ProviderErrorCopy.detail(from: http.statusCode, host: "ollama.com", body: body)
            )
        }
        return try JSONDecoder().decode(BalanceResponse.self, from: data)
    }
}

struct ProviderFetchError: Error {
    let userMessage: String
    let detail: String
}
