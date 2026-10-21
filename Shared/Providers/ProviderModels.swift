import Foundation

enum ProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case cursor
    case claude
    case codex
    case ollamaCloud = "ollama-cloud"
    case opencodeGo = "opencode-go"
    case copilot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .ollamaCloud: return "Ollama Cloud"
        case .opencodeGo: return "OpenCode Go"
        case .copilot: return "Copilot"
        }
    }

    var symbolName: String {
        switch self {
        case .cursor: return "sparkles"
        case .claude: return "brain.head.profile"
        case .codex: return "terminal"
        case .ollamaCloud: return "cloud"
        case .opencodeGo: return "chevron.left.forwardslash.chevron.right"
        case .copilot: return "airplane"
        }
    }
}

struct UsageWindow: Codable, Equatable, Sendable, Identifiable {
    var id: String { label }
    /// Short label: "5h", "weekly", "month", "Auto", "API", …
    var label: String
    /// 0...1 used fraction
    var fraction: Double?
    var resetsAt: Date?
}

struct ProviderUsage: Codable, Equatable, Sendable, Identifiable {
    var id: String { providerID.rawValue }
    var providerID: ProviderID
    var status: SnapshotStatus
    var planName: String
    var email: String?
    var windows: [UsageWindow]
    var displayMessage: String?
    var errorMessage: String?
    var fetchedAt: Date

    /// Cursor-only extras (ignored by other providers).
    var tokenStats: TokenStats?
    var topModels: [ModelUsage]
    var includedSpend: Double?
    var totalSpend: Double?
    var onDemandEnabled: Bool
    var onDemandUsedCents: Double?

    var primaryFraction: Double? {
        windows.compactMap(\.fraction).max()
            ?? windows.first?.fraction
    }

    static func empty(_ provider: ProviderID) -> ProviderUsage {
        ProviderUsage(
            providerID: provider,
            status: .missing,
            planName: "—",
            email: nil,
            windows: [],
            displayMessage: nil,
            errorMessage: nil,
            fetchedAt: .distantPast,
            tokenStats: nil,
            topModels: [],
            includedSpend: nil,
            totalSpend: nil,
            onDemandEnabled: false,
            onDemandUsedCents: nil
        )
    }

    static func authMissing(_ provider: ProviderID, message: String) -> ProviderUsage {
        var snap = empty(provider)
        snap.status = .authMissing
        snap.errorMessage = message
        snap.fetchedAt = Date()
        return snap
    }

}

/// Aggregate written for the host + widgets (+ external readers such as Cyclop).
struct AppSnapshot: Codable, Equatable, Sendable {
    /// Bump when making breaking JSON changes. Missing key ⇒ treat as 1.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var fetchedAt: Date
    var providers: [ProviderUsage]
    var enabledProviderIDs: [ProviderID]
    var primaryProviderID: ProviderID

    var primary: ProviderUsage? {
        providers.first(where: { $0.providerID == primaryProviderID })
            ?? providers.first(where: { $0.status == .ok })
            ?? providers.first
    }

    static var empty: AppSnapshot {
        AppSnapshot(
            schemaVersion: currentSchemaVersion,
            fetchedAt: .distantPast,
            providers: [],
            enabledProviderIDs: AppPreferencesStore.defaultEnabled,
            primaryProviderID: .cursor
        )
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, fetchedAt, providers, enabledProviderIDs, primaryProviderID
    }

    init(
        schemaVersion: Int = AppSnapshot.currentSchemaVersion,
        fetchedAt: Date,
        providers: [ProviderUsage],
        enabledProviderIDs: [ProviderID],
        primaryProviderID: ProviderID
    ) {
        self.schemaVersion = schemaVersion
        self.fetchedAt = fetchedAt
        self.providers = providers
        self.enabledProviderIDs = enabledProviderIDs
        self.primaryProviderID = primaryProviderID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        fetchedAt = try c.decode(Date.self, forKey: .fetchedAt)
        providers = try c.decode([ProviderUsage].self, forKey: .providers)
        enabledProviderIDs = try c.decode([ProviderID].self, forKey: .enabledProviderIDs)
        primaryProviderID = try c.decode(ProviderID.self, forKey: .primaryProviderID)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(fetchedAt, forKey: .fetchedAt)
        try c.encode(providers, forKey: .providers)
        try c.encode(enabledProviderIDs, forKey: .enabledProviderIDs)
        try c.encode(primaryProviderID, forKey: .primaryProviderID)
    }
}
