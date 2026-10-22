import Foundation
import SwiftUI

enum Formatters {
    static func percent(_ fraction: Double?) -> String {
        guard let fraction else { return "—" }
        return String(format: "%.0f%%", fraction * 100)
    }

    /// Menu bar label: `82%` or `82% · 4d` when a reset date is known.
    static func compactMenuBarTitle(fraction: Double?, resetAt: Date?, includeReset: Bool) -> String {
        let pct = percent(fraction)
        guard includeReset, let resetAt else { return pct }
        let days = compactDaysUntilReset(resetAt)
        guard !days.isEmpty else { return pct }
        return "\(pct) · \(days)"
    }

    /// Ultra-short countdown for the menu bar (`4d` / `4д`, `today` / `сег.`).
    static func compactDaysUntilReset(_ date: Date?) -> String {
        guard let date else { return "" }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if L10n.isRussian {
            switch days {
            case ...(-1): return "сейч."
            case 0: return "сег."
            case 1: return "завт."
            default: return "\(days)д"
            }
        }
        switch days {
        case ...(-1): return "now"
        case 0: return "today"
        case 1: return "tmrw"
        default: return "\(days)d"
        }
    }

    static func percentLabel(_ fraction: Double?) -> String {
        guard let fraction else { return "н/д" }
        return String(format: "%.0f%%", min(max(fraction, 0), 9.99) * 100)
    }

    static func compactNumber(_ value: Int) -> String {
        let absValue = abs(value)
        switch absValue {
        case 1_000_000_000...:
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 10_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
        }
    }

    static func dollars(fromCents cents: Double?) -> String {
        guard let cents else { return "—" }
        return String(format: "$%.2f", cents / 100.0)
    }

    static func dollars(_ amount: Double?) -> String {
        guard let amount else { return "—" }
        // Heuristic: values > 1000 are likely cents already represented as spend dollars in some payloads.
        if amount > 500, amount == floor(amount), amount.truncatingRemainder(dividingBy: 1) == 0 {
            // treat as dollars if looks like dollar spend from planUsage.totalSpend
        }
        return String(format: "$%.2f", amount)
    }

    static func spendDisplay(totalSpend: Double?, includedSpend: Double?) -> String {
        if let totalSpend { return String(format: "$%.2f", totalSpend) }
        if let includedSpend { return String(format: "$%.2f", includedSpend) }
        return "—"
    }

    static func relativeReset(_ date: Date?) -> String {
        daysUntilReset(date)
    }

    /// e.g. "12 дн." / "12 days", "сегодня" / "today"
    static func daysUntilReset(_ date: Date?) -> String {
        guard let date else { return "—" }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if L10n.isRussian {
            switch days {
            case ...(-1): return "сейчас"
            case 0: return "сегодня"
            case 1: return "завтра"
            default: return "\(days) дн."
            }
        }
        switch days {
        case ...(-1): return "now"
        case 0: return "today"
        case 1: return "tomorrow"
        case 2: return "2 days"
        default: return "\(days) days"
        }
    }

    static func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.locale = L10n.isRussian ? Locale(identifier: "ru_RU") : Locale(identifier: "en_US")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    static func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = L10n.isRussian ? Locale(identifier: "ru_RU") : Locale(identifier: "en_US")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func usageColor(_ fraction: Double?) -> Color {
        guard let fraction else { return .secondary }
        switch fraction {
        case ..<0.6: return Color(red: 0.20, green: 0.72, blue: 0.45)
        case ..<0.85: return Color(red: 0.95, green: 0.68, blue: 0.18)
        default: return Color(red: 0.92, green: 0.32, blue: 0.28)
        }
    }

    static func shortModelName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "gpt-", with: "")
            .replacingOccurrences(of: "-thinking", with: "")
            .replacingOccurrences(of: "composer-", with: "comp-")
    }
}
