import Foundation

struct ProviderDiagnosticEntry: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var providerID: ProviderID
    var createdAt: Date
    var summary: String
    var detail: String
}

/// Local-only error log for Settings. Never uploaded; secrets are redacted before write.
enum ProviderDiagnosticsStore {
    private static let fileName = "diagnostics.json"
    private static let maxEntries = 40
    /// Serializes read-modify-write across parallel provider refreshes.
    private static let queue = DispatchQueue(label: "com.5tepan.cursorlimits.diagnostics")

    private static var fileURL: URL {
        AppPaths.applicationSupportDirectoryURL.appendingPathComponent(fileName)
    }

    static func record(provider: ProviderID, summary: String, detail: String) {
        queue.sync {
            var all = loadAllUnlocked()
            let entry = ProviderDiagnosticEntry(
                id: UUID().uuidString,
                providerID: provider,
                createdAt: Date(),
                summary: SecretRedactor.redact(summary),
                detail: SecretRedactor.redact(detail)
            )
            all.insert(entry, at: 0)
            if all.count > maxEntries {
                all = Array(all.prefix(maxEntries))
            }
            saveUnlocked(all)
        }
    }

    static func entries(for provider: ProviderID) -> [ProviderDiagnosticEntry] {
        queue.sync {
            loadAllUnlocked().filter { $0.providerID == provider }
        }
    }

    static func latest(for provider: ProviderID) -> ProviderDiagnosticEntry? {
        entries(for: provider).first
    }

    static func clear(provider: ProviderID) {
        queue.sync {
            saveUnlocked(loadAllUnlocked().filter { $0.providerID != provider })
        }
    }

    private static func loadAllUnlocked() -> [ProviderDiagnosticEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ProviderDiagnosticEntry].self, from: data)) ?? []
    }

    private static func saveUnlocked(_ entries: [ProviderDiagnosticEntry]) {
        try? SnapshotStore.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

enum ProviderErrorCopy {
    /// Short, human-readable status line for Settings / menu bar.
    static func shortStatus(for usage: ProviderUsage, enabled: Bool) -> String {
        guard enabled else { return L10n.t("Выключен", "Off") }
        switch usage.status {
        case .ok:
            let pct = Formatters.percent(usage.primaryFraction)
            if usage.planName != "—", !usage.planName.isEmpty {
                return "\(usage.planName) · \(pct)"
            }
            return pct
        case .authMissing:
            return L10n.t("Нет сессии", "No session")
        case .missing:
            return L10n.noDataTitle
        case .error:
            return humanize(usage.errorMessage) ?? L10n.t("Ошибка обновления", "Refresh failed")
        }
    }

    static func humanize(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        if lower.contains("401") || lower.contains("unauthorized") || lower.contains("invalid credential") {
            return L10n.t("Неверный или устаревший ключ", "Invalid or expired key")
        }
        if lower.contains("403") || lower.contains("forbidden") || lower.contains("suspended") {
            return L10n.t("Доступ запрещён", "Access denied")
        }
        if lower.contains("404") {
            return L10n.t("Сервис не найден", "Service not found")
        }
        if lower.contains("429") || lower.contains("rate limit") {
            return L10n.t("Слишком много запросов", "Too many requests")
        }
        if lower.contains("timed out") || lower.contains("timeout") {
            return L10n.t("Таймаут сети", "Network timeout")
        }
        if lower.contains("offline") || lower.contains("internet") || lower.contains("network")
            || lower.contains("could not connect") || lower.contains("nsurlerrordomain")
        {
            return L10n.t("Нет сети", "Network unavailable")
        }
        if let code = firstHTTPCode(in: raw) {
            return L10n.t("Ошибка сервера (\(code))", "Server error (\(code))")
        }
        // Already short / human — keep, but never show raw JSON blobs inline
        if raw.contains("{"), raw.count > 60 {
            return L10n.t("Ошибка обновления", "Refresh failed")
        }
        if raw.count > 80 {
            return L10n.t("Ошибка обновления", "Refresh failed")
        }
        return raw
    }

    static func detail(from statusCode: Int, host: String, body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = trimmed.isEmpty ? "(empty body)" : String(trimmed.prefix(1_500))
        return """
        host: \(host)
        http: \(statusCode)
        body:
        \(snippet)
        """
    }

    private static func firstHTTPCode(in text: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: #"\bHTTP\s+(\d{3})\b"#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex?.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text)
        else { return nil }
        return Int(text[r])
    }
}

extension ProviderUsage {
    static func failed(
        _ provider: ProviderID,
        userMessage: String,
        technicalDetail: String? = nil
    ) -> ProviderUsage {
        let detail = technicalDetail ?? userMessage
        ProviderDiagnosticsStore.record(
            provider: provider,
            summary: userMessage,
            detail: detail
        )
        var snap = empty(provider)
        snap.status = .error
        snap.errorMessage = userMessage
        snap.fetchedAt = Date()
        return snap
    }
}
