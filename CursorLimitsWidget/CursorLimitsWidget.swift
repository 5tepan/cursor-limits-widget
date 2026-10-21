import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let snapshot = SnapshotStore.load() ?? .preview
        completion(UsageEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        var snapshot = SnapshotStore.load() ?? UsageSnapshot.empty
        if snapshot.status == .missing {
            // Host hasn't written yet / path mismatch — show a clearer empty state.
            snapshot.errorMessage = L10n.runAppHint
        }
        let entry = UsageEntry(date: Date(), snapshot: snapshot)
        // Host app refreshes the snapshot; widget reloads frequently until data appears.
        let minutes = snapshot.status == .ok ? 15 : 5
        let next = Calendar.current.date(byAdding: .minute, value: minutes, to: Date())
            ?? Date().addingTimeInterval(TimeInterval(minutes * 60))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct CursorLimitsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallUsageView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumUsageView(snapshot: entry.snapshot)
        case .systemLarge:
            LargeUsageView(snapshot: entry.snapshot)
        default:
            MediumUsageView(snapshot: entry.snapshot)
        }
    }
}

struct CursorLimitsWidget: Widget {
    let kind = "CursorLimitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CursorLimitsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cursor Limits")
        .description("Лимиты подписки Cursor, токены и сброс цикла.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct CursorLimitsWidgetBundle: WidgetBundle {
    var body: some Widget {
        CursorLimitsWidget()
    }
}

extension UsageSnapshot {
    static var preview: UsageSnapshot {
        UsageSnapshot(
            fetchedAt: Date(),
            email: "you@example.com",
            planName: "Pro",
            membershipType: "pro",
            billingCycleStart: Calendar.current.date(byAdding: .day, value: -12, to: Date()),
            billingCycleEnd: Calendar.current.date(byAdding: .day, value: 18, to: Date()),
            autoPercentUsed: 0.42,
            apiPercentUsed: 0.67,
            totalPercentUsed: 0.55,
            planUsed: 110,
            planLimit: 200,
            planRemaining: 90,
            includedSpend: 11.2,
            totalSpend: 14.8,
            bonusSpend: 0,
            onDemandEnabled: true,
            onDemandUsedCents: 320,
            onDemandLimitCents: 2000,
            displayMessage: nil,
            tokenStats: TokenStats(
                inputTokens: 1_240_000,
                outputTokens: 380_000,
                cacheReadTokens: 4_200_000,
                cacheWriteTokens: 910_000,
                eventCount: 186,
                chargedCents: 1480
            ),
            topModels: [
                ModelUsage(name: "composer-2", requests: 92, tokens: 2_100_000, chargedCents: 420),
                ModelUsage(name: "claude-4.6-sonnet", requests: 41, tokens: 1_800_000, chargedCents: 610),
                ModelUsage(name: "gpt-5.3", requests: 28, tokens: 900_000, chargedCents: 280)
            ],
            status: .ok,
            errorMessage: nil
        )
    }
}
