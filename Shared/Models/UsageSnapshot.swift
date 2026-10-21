import Foundation

/// Shared snapshot written by the host app and read by the widget.
struct UsageSnapshot: Codable, Equatable, Sendable {
    var fetchedAt: Date
    var email: String?
    var planName: String
    var membershipType: String?

    var billingCycleStart: Date?
    var billingCycleEnd: Date?

    /// 0...1 fractions for included pools.
    var autoPercentUsed: Double?
    var apiPercentUsed: Double?
    var totalPercentUsed: Double?

    var planUsed: Double?
    var planLimit: Double?
    var planRemaining: Double?

    var includedSpend: Double?
    var totalSpend: Double?
    var bonusSpend: Double?

    var onDemandEnabled: Bool
    var onDemandUsedCents: Double?
    var onDemandLimitCents: Double?

    var displayMessage: String?

    /// Aggregated token stats for the current billing cycle (best-effort).
    var tokenStats: TokenStats?

    /// Top models by request count in the current cycle.
    var topModels: [ModelUsage]

    var status: SnapshotStatus
    var errorMessage: String?

    static var empty: UsageSnapshot {
        UsageSnapshot(
            fetchedAt: .distantPast,
            email: nil,
            planName: "—",
            membershipType: nil,
            billingCycleStart: nil,
            billingCycleEnd: nil,
            autoPercentUsed: nil,
            apiPercentUsed: nil,
            totalPercentUsed: nil,
            planUsed: nil,
            planLimit: nil,
            planRemaining: nil,
            includedSpend: nil,
            totalSpend: nil,
            bonusSpend: nil,
            onDemandEnabled: false,
            onDemandUsedCents: nil,
            onDemandLimitCents: nil,
            displayMessage: nil,
            tokenStats: nil,
            topModels: [],
            status: .missing,
            errorMessage: nil
        )
    }
}

enum SnapshotStatus: String, Codable, Sendable {
    case ok
    case missing
    case authMissing
    case error
}

struct TokenStats: Codable, Equatable, Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheReadTokens: Int
    var cacheWriteTokens: Int
    var eventCount: Int
    var chargedCents: Double

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
    }
}

struct ModelUsage: Codable, Equatable, Sendable, Identifiable {
    var id: String { name }
    var name: String
    var requests: Int
    var tokens: Int
    var chargedCents: Double
}
