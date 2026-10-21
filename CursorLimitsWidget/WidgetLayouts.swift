import SwiftUI

struct WidgetChrome<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
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
    var snapshot: UsageSnapshot

    var body: some View {
        WidgetChrome(title: snapshot.planName, subtitle: Formatters.daysUntilReset(snapshot.billingCycleEnd)) {
            if snapshot.status != .ok {
                StatusPlaceholder(snapshot: snapshot)
            } else {
                HStack(spacing: 12) {
                    ProgressRing(progress: primaryFraction, lineWidth: 7, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(Formatters.percent(primaryFraction))
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text("\(L10n.resetIn) \(Formatters.daysUntilReset(snapshot.billingCycleEnd))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private var primaryFraction: Double? {
        snapshot.totalPercentUsed ?? snapshot.apiPercentUsed ?? snapshot.autoPercentUsed
    }

    private var primaryLabel: String {
        if snapshot.totalPercentUsed != nil { return "Всего" }
        if snapshot.apiPercentUsed != nil { return "API" }
        return "Auto"
    }
}

struct MediumUsageView: View {
    var snapshot: UsageSnapshot

    var body: some View {
        WidgetChrome(
            title: snapshot.planName,
            subtitle: snapshot.fetchedAt == .distantPast ? nil : Formatters.timeAgo(snapshot.fetchedAt)
        ) {
            if snapshot.status != .ok {
                StatusPlaceholder(snapshot: snapshot)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 14) {
                        ProgressRing(progress: snapshot.totalPercentUsed ?? snapshot.apiPercentUsed, lineWidth: 8, size: 62)
                        VStack(alignment: .leading, spacing: 8) {
                            UsageBar(title: "Auto", fraction: snapshot.autoPercentUsed)
                            UsageBar(title: "API", fraction: snapshot.apiPercentUsed)
                        }
                    }

                    HStack(spacing: 12) {
                        MetricChip(label: L10n.resetIn, value: Formatters.daysUntilReset(snapshot.billingCycleEnd))
                        MetricChip(label: L10n.spent, value: Formatters.spendDisplay(totalSpend: snapshot.totalSpend, includedSpend: snapshot.includedSpend))
                        if snapshot.onDemandEnabled {
                            MetricChip(
                                label: L10n.onDemand,
                                value: Formatters.dollars(fromCents: snapshot.onDemandUsedCents)
                            )
                        } else if let tokens = snapshot.tokenStats {
                            MetricChip(label: L10n.t("Токены", "Tokens"), value: Formatters.compactNumber(tokens.totalTokens))
                        }
                    }
                }
            }
        }
    }
}

struct LargeUsageView: View {
    var snapshot: UsageSnapshot

    var body: some View {
        WidgetChrome(
            title: "Cursor · \(snapshot.planName)",
            subtitle: snapshot.email
        ) {
            if snapshot.status != .ok {
                StatusPlaceholder(snapshot: snapshot)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        ProgressRing(
                            progress: snapshot.totalPercentUsed ?? snapshot.apiPercentUsed,
                            lineWidth: 10,
                            size: 78
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            UsageBar(title: "Auto / Composer", fraction: snapshot.autoPercentUsed)
                            UsageBar(title: "API / Named models", fraction: snapshot.apiPercentUsed)
                            HStack {
                                Text("\(L10n.t("Цикл до", "Cycle ends")) \(Formatters.shortDate(snapshot.billingCycleEnd))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(L10n.resetIn) \(Formatters.daysUntilReset(snapshot.billingCycleEnd))")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }

                    if let tokens = snapshot.tokenStats {
                        HStack(spacing: 10) {
                            MetricChip(label: "Input", value: Formatters.compactNumber(tokens.inputTokens))
                            MetricChip(label: "Output", value: Formatters.compactNumber(tokens.outputTokens))
                            MetricChip(label: "Cache", value: Formatters.compactNumber(tokens.cacheReadTokens + tokens.cacheWriteTokens))
                            MetricChip(label: L10n.t("Запросы", "Requests"), value: "\(tokens.eventCount)")
                        }
                    }

                    HStack(spacing: 10) {
                        MetricChip(
                            label: L10n.t("В лимите", "Included"),
                            value: Formatters.spendDisplay(totalSpend: snapshot.includedSpend, includedSpend: nil)
                        )
                        MetricChip(
                            label: L10n.spent,
                            value: Formatters.spendDisplay(totalSpend: snapshot.totalSpend, includedSpend: nil)
                        )
                        if snapshot.onDemandEnabled {
                            MetricChip(
                                label: L10n.onDemand,
                                value: Formatters.dollars(fromCents: snapshot.onDemandUsedCents)
                            )
                        }
                    }

                    if !snapshot.topModels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.topModels)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(snapshot.topModels.prefix(4)) { model in
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

                    Text("\(L10n.updated) \(Formatters.timeAgo(snapshot.fetchedAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
