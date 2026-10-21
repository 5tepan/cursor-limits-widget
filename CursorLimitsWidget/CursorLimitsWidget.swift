import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let snapshot = AppSnapshotStore.load() ?? .preview
        completion(UsageEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        var snapshot = AppSnapshotStore.load() ?? AppSnapshot.empty
        if snapshot.primary?.status == .missing || snapshot.providers.isEmpty {
            // Host hasn't written yet — keep empty state clear.
            if var primary = snapshot.primary {
                primary.errorMessage = L10n.runAppHint
                snapshot.providers = [primary]
            }
        }
        let entry = UsageEntry(date: Date(), snapshot: snapshot)
        let ok = snapshot.primary?.status == .ok
        let minutes = ok ? 15 : 5
        let next = Calendar.current.date(byAdding: .minute, value: minutes, to: Date())
            ?? Date().addingTimeInterval(TimeInterval(minutes * 60))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: AppSnapshot
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
        .description(L10n.t(
            "Лимиты Cursor, Claude, Codex, OpenCode Go и Copilot.",
            "Usage limits for Cursor, Claude, Codex, OpenCode Go, and Copilot."
        ))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct CursorLimitsWidgetBundle: WidgetBundle {
    var body: some Widget {
        CursorLimitsWidget()
    }
}

extension AppSnapshot {
    static var preview: AppSnapshot {
        AppSnapshot(
            fetchedAt: Date(),
            providers: [
                ProviderUsage(
                    providerID: .cursor,
                    status: .ok,
                    planName: "Pro",
                    email: "you@example.com",
                    windows: [
                        UsageWindow(label: "Auto", fraction: 0.42, resetsAt: Calendar.current.date(byAdding: .day, value: 18, to: Date())),
                        UsageWindow(label: "API", fraction: 0.67, resetsAt: Calendar.current.date(byAdding: .day, value: 18, to: Date()))
                    ],
                    displayMessage: nil,
                    errorMessage: nil,
                    fetchedAt: Date(),
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
                    includedSpend: 11.2,
                    totalSpend: 14.8,
                    onDemandEnabled: true,
                    onDemandUsedCents: 320
                )
            ],
            enabledProviderIDs: AppPreferencesStore.defaultEnabled,
            primaryProviderID: .cursor
        )
    }
}
