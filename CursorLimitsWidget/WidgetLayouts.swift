import SwiftUI

struct WidgetChrome<Content: View>: View {
    var title: String
    var subtitle: String?
    var symbolName: String = "sparkles"
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.20))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.12, blue: 0.14),
                    Color(red: 0.16, green: 0.17, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .foregroundStyle(.white)
    }
}

struct SmallUsageView: View {
    var snapshot: AppSnapshot

    private var usage: ProviderUsage? { snapshot.primary }

    var body: some View {
        let reset = usage?.windows.compactMap(\.resetsAt).max()
        WidgetChrome(
            title: usage?.planName ?? L10n.appName,
            subtitle: Formatters.daysUntilReset(reset),
            symbolName: usage?.providerID.symbolName ?? "sparkles"
        ) {
            if let usage, usage.status == .ok {
                HStack(spacing: 12) {
                    ProgressRing(progress: usage.primaryFraction, lineWidth: 7, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryLabel(usage))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(Formatters.percent(usage.primaryFraction))
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text("\(L10n.resetIn) \(Formatters.daysUntilReset(reset))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                StatusPlaceholder(usage: usage)
            }
        }
    }

    private func primaryLabel(_ usage: ProviderUsage) -> String {
        usage.windows.first?.label ?? usage.providerID.displayName
    }
}

struct MediumUsageView: View {
    var snapshot: AppSnapshot

    private var usage: ProviderUsage? { snapshot.primary }

    var body: some View {
        WidgetChrome(
            title: usage.map { "\($0.providerID.displayName) · \($0.planName)" } ?? L10n.appName,
            subtitle: snapshot.fetchedAt == .distantPast ? nil : Formatters.timeAgo(snapshot.fetchedAt),
            symbolName: usage?.providerID.symbolName ?? "sparkles"
        ) {
            if let usage, usage.status == .ok {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 14) {
                        ProgressRing(progress: usage.primaryFraction, lineWidth: 8, size: 62)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(usage.windows.prefix(3)) { window in
                                UsageBar(title: window.label, fraction: window.fraction)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        let reset = usage.windows.compactMap(\.resetsAt).max()
                        MetricChip(label: L10n.resetIn, value: Formatters.daysUntilReset(reset))
                        if usage.totalSpend != nil || usage.includedSpend != nil {
                            MetricChip(
                                label: L10n.spent,
                                value: Formatters.spendDisplay(
                                    totalSpend: usage.totalSpend,
                                    includedSpend: usage.includedSpend
                                )
                            )
                        }
                        if usage.onDemandEnabled {
                            MetricChip(
                                label: L10n.onDemand,
                                value: Formatters.dollars(fromCents: usage.onDemandUsedCents)
                            )
                        } else if let tokens = usage.tokenStats {
                            MetricChip(label: L10n.t("Токены", "Tokens"), value: Formatters.compactNumber(tokens.totalTokens))
                        } else if let fraction = usage.primaryFraction {
                            MetricChip(label: L10n.t("Использовано", "Used"), value: Formatters.percent(fraction))
                        }
                    }
                }
            } else {
                StatusPlaceholder(usage: usage)
            }
        }
    }
}

struct LargeUsageView: View {
    var snapshot: AppSnapshot

    private var usage: ProviderUsage? { snapshot.primary }

    var body: some View {
        WidgetChrome(
            title: usage.map { "\($0.providerID.displayName) · \($0.planName)" } ?? L10n.appName,
            subtitle: usage?.email,
            symbolName: usage?.providerID.symbolName ?? "sparkles"
        ) {
            if let usage, usage.status == .ok {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        ProgressRing(
                            progress: usage.primaryFraction,
                            lineWidth: 10,
                            size: 78
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(usage.windows) { window in
                                UsageBar(title: windowLabel(window), fraction: window.fraction)
                            }
                            if let reset = usage.windows.compactMap(\.resetsAt).max() {
                                HStack {
                                    Text("\(L10n.t("Цикл до", "Cycle ends")) \(Formatters.shortDate(reset))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(L10n.resetIn) \(Formatters.daysUntilReset(reset))")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                        }
                    }

                    if let tokens = usage.tokenStats {
                        HStack(spacing: 10) {
                            MetricChip(label: "Input", value: Formatters.compactNumber(tokens.inputTokens))
                            MetricChip(label: "Output", value: Formatters.compactNumber(tokens.outputTokens))
                            MetricChip(label: "Cache", value: Formatters.compactNumber(tokens.cacheReadTokens + tokens.cacheWriteTokens))
                            MetricChip(label: L10n.t("Запросы", "Requests"), value: "\(tokens.eventCount)")
                        }
                    }

                    if usage.includedSpend != nil || usage.totalSpend != nil || usage.onDemandEnabled {
                        HStack(spacing: 10) {
                            MetricChip(
                                label: L10n.t("В лимите", "Included"),
                                value: Formatters.spendDisplay(totalSpend: usage.includedSpend, includedSpend: nil)
                            )
                            MetricChip(
                                label: L10n.spent,
                                value: Formatters.spendDisplay(totalSpend: usage.totalSpend, includedSpend: nil)
                            )
                            if usage.onDemandEnabled {
                                MetricChip(
                                    label: L10n.onDemand,
                                    value: Formatters.dollars(fromCents: usage.onDemandUsedCents)
                                )
                            }
                        }
                    }

                    if !usage.topModels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.topModels)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(usage.topModels.prefix(4)) { model in
                                HStack {
                                    Text(Formatters.shortModelName(model.name))
                                        .font(.caption.monospaced())
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(model.requests)×")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Text(Formatters.compactNumber(model.tokens))
                                        .font(.caption.monospacedDigit())
                                        .frame(minWidth: 44, alignment: .trailing)
                                }
                            }
                        }
                    }

                    // Compact strip of other enabled providers
                    let others = snapshot.providers.filter {
                        $0.providerID != usage.providerID && $0.status == .ok
                    }
                    if !others.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(others.prefix(4)) { other in
                                MetricChip(
                                    label: other.providerID.displayName,
                                    value: Formatters.percent(other.primaryFraction)
                                )
                            }
                        }
                    }

                    Text("\(L10n.updated) \(Formatters.timeAgo(snapshot.fetchedAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                StatusPlaceholder(usage: usage)
            }
        }
    }

    private func windowLabel(_ window: UsageWindow) -> String {
        switch window.label {
        case "Auto": return "Auto / Composer"
        case "API": return "API / Named models"
        default: return window.label
        }
    }
}
