import Foundation

enum UsageFraction {
    /// Normalize API percent values that may be 0…1 or 0…100.
    static func normalize(_ value: Double) -> Double {
        let scaled = value > 1.5 ? value / 100.0 : value
        return min(max(scaled, 0), 1)
    }

    /// Remaining budget as 0…1 used fraction (e.g. Ollama remaining percent).
    static func usedFromRemaining(_ remaining: Double) -> Double {
        1.0 - normalize(remaining)
    }
}
