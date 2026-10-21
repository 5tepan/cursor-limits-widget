import Foundation

struct OpenCodeGoUsageProvider: UsageProvider {
    let id: ProviderID = .opencodeGo

    /// Only explicit OpenCode Go identifiers — never ollama / openrouter / empty fallbacks.
    private static let aliases = [
        "opencode-go",
        "opencode_go",
        "opencode.go",
        "zen-go",
        "zen_go"
    ]

    func isAvailable() -> Bool {
        Self.loadAPIKey() != nil
    }

    func refresh() async -> ProviderUsage {
        guard let key = Self.loadAPIKey() else {
            return .authMissing(.opencodeGo, message: L10n.t(
                "Подключите OpenCode Go (/connect) на этом Mac.",
                "Connect OpenCode Go (/connect) on this Mac."
            ))
        }

        do {
            let usage = try await Self.fetchUsage(apiKey: key)
            var windows: [UsageWindow] = []
            if let rolling = usage.usage?.rolling {
                windows.append(UsageWindow(
                    label: "5h",
                    fraction: rolling.fraction,
                    resetsAt: rolling.resetDate
                ))
            }
            if let weekly = usage.usage?.weekly {
                windows.append(UsageWindow(
                    label: "weekly",
                    fraction: weekly.fraction,
                    resetsAt: weekly.resetDate
                ))
            }
            if let monthly = usage.usage?.monthly {
                windows.append(UsageWindow(
                    label: "month",
                    fraction: monthly.fraction,
                    resetsAt: monthly.resetDate
                ))
            }
            return ProviderUsage(
                providerID: .opencodeGo,
                status: .ok,
                planName: usage.plan ?? "OpenCode Go",
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
            return .failed(.opencodeGo, userMessage: error.userMessage, technicalDetail: error.detail)
        } catch {
            return .failed(
                .opencodeGo,
                userMessage: L10n.t("Ошибка обновления", "Refresh failed"),
                technicalDetail: error.localizedDescription
            )
        }
    }

    private static func loadAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["OPENCODE_GO_API_KEY"], !env.isEmpty {
            return env
        }
        // Deliberately NOT OPENCODE_API_KEY — too easy to point at the wrong product.
        return OpenCodeAuthStore.apiKey(matching: aliases)
    }

    private struct Meter: Decodable {
        let percent: Double?
        let resetsAt: String?
        let resetInSec: Double?

        enum CodingKeys: String, CodingKey {
            case percent, resetsAt, resetInSec
            case resets_at, reset_in_sec
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            percent = try c.decodeIfPresent(Double.self, forKey: .percent)
            resetsAt = try c.decodeIfPresent(String.self, forKey: .resetsAt)
                ?? c.decodeIfPresent(String.self, forKey: .resets_at)
            resetInSec = try c.decodeIfPresent(Double.self, forKey: .resetInSec)
                ?? c.decodeIfPresent(Double.self, forKey: .reset_in_sec)
        }

        var fraction: Double? {
            guard let percent else { return nil }
            return percent > 1.5 ? min(percent / 100.0, 1) : min(max(percent, 0), 1)
        }

        var resetDate: Date? {
            if let resetsAt {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = f.date(from: resetsAt) { return d }
                f.formatOptions = [.withInternetDateTime]
                return f.date(from: resetsAt)
            }
            if let resetInSec {
                return Date().addingTimeInterval(resetInSec)
            }
            return nil
        }
    }

    private struct UsageBlock: Decodable {
        let rolling: Meter?
        let weekly: Meter?
        let monthly: Meter?
    }

    private struct Response: Decodable {
        let usage: UsageBlock?
        let plan: String?
    }

    private static func fetchUsage(apiKey: String) async throws -> Response {
        let url = URL(string: "https://opencode.ai/zen/go/v1/usage")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderFetchError(
                userMessage: L10n.t("Ошибка обновления", "Refresh failed"),
                detail: "Invalid response from opencode.ai"
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderFetchError(
                userMessage: ProviderErrorCopy.humanize("HTTP \(http.statusCode): \(body)")
                    ?? L10n.t("Ошибка обновления", "Refresh failed"),
                detail: ProviderErrorCopy.detail(from: http.statusCode, host: "opencode.ai", body: body)
            )
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
