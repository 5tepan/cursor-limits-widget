import Foundation

protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    /// True when local credentials/files look present (not necessarily valid).
    func isAvailable() -> Bool
    func refresh() async -> ProviderUsage
}

enum ProviderRegistry {
    static let all: [any UsageProvider] = [
        CursorUsageProvider(),
        ClaudeUsageProvider(),
        CodexUsageProvider(),
        OllamaCloudUsageProvider(),
        OpenCodeGoUsageProvider(),
        CopilotUsageProvider()
    ]

    static func provider(for id: ProviderID) -> (any UsageProvider)? {
        all.first { $0.id == id }
    }
}
