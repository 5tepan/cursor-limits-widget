import SwiftUI

// MARK: - Shared chrome

struct WidgetChrome<Content: View>: View {
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 10
    var updatedAt: Date?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("BrandIcon")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                Text(L10n.appName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let updatedAt, updatedAt != .distantPast {
                    Text(Formatters.timeAgo(updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            content
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
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

private extension AppSnapshot {
    /// Primary first, then other OK providers in stable order.
    var okProvidersPrimaryFirst: [ProviderUsage] {
        let ok = providers.filter { $0.status == .ok }
        let primaryID = primaryProviderID
        return ok.sorted { a, b in
            if a.providerID == primaryID { return true }
            if b.providerID == primaryID { return false }
            let ia = ProviderID.allCases.firstIndex(of: a.providerID) ?? 0
            let ib = ProviderID.allCases.firstIndex(of: b.providerID) ?? 0
            return ia < ib
        }
    }
}

private func providerPlanTitle(_ usage: ProviderUsage) -> String {
    if usage.planName != "—", !usage.planName.isEmpty {
        return "\(usage.providerID.displayName) · \(usage.planName)"
    }
    return usage.providerID.displayName
}

// MARK: - Small: primary only, ring-centric

struct SmallUsageView: View {
    var snapshot: AppSnapshot

    private var usage: ProviderUsage? { snapshot.primary }

    var body: some View {
        WidgetChrome(
            horizontalPadding: 8,
            verticalPadding: 8,
            updatedAt: snapshot.fetchedAt
        ) {
            if let usage, usage.status == .ok {
                VStack(alignment: .leading, spacing: 10) {
                    Text(providerPlanTitle(usage))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    ProgressRing(progress: usage.primaryFraction, lineWidth: 7, size: 72)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                StatusPlaceholder(usage: usage)
            }
        }
    }
}

// MARK: - Medium: up to 3 compact columns (ring only)

struct MediumUsageView: View {
    var snapshot: AppSnapshot

    private var visible: [ProviderUsage] {
        Array(snapshot.okProvidersPrimaryFirst.prefix(3))
    }

    private var overflowCount: Int {
        max(0, snapshot.okProvidersPrimaryFirst.count - 3)
    }

    var body: some View {
        WidgetChrome(
            horizontalPadding: 8,
            verticalPadding: 10,
            updatedAt: snapshot.fetchedAt
        ) {
            if visible.isEmpty {
                StatusPlaceholder(usage: snapshot.primary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(visible) { usage in
                            MediumProviderColumn(usage: usage)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    if overflowCount > 0 {
                        Text(L10n.moreInMenuBar)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

private struct MediumProviderColumn: View {
    let usage: ProviderUsage

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Text(providerPlanTitle(usage))
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
            ProgressRing(progress: usage.primaryFraction, lineWidth: 6, size: 56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Large: up to 3 detailed cards (ring + bars, as in screenshot)

struct LargeUsageView: View {
    var snapshot: AppSnapshot

    private var visible: [ProviderUsage] {
        Array(snapshot.okProvidersPrimaryFirst.prefix(3))
    }

    private var overflowCount: Int {
        max(0, snapshot.okProvidersPrimaryFirst.count - 3)
    }

    var body: some View {
        WidgetChrome(
            horizontalPadding: 8,
            verticalPadding: 12,
            updatedAt: snapshot.fetchedAt
        ) {
            if visible.isEmpty {
                StatusPlaceholder(usage: snapshot.primary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(visible) { usage in
                        LargeProviderBlock(usage: usage)
                    }
                    if overflowCount > 0 {
                        Text(L10n.moreInMenuBar)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

/// Matches the screenshot: title, ring with %, bars for windows on the right.
private struct LargeProviderBlock: View {
    let usage: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(providerPlanTitle(usage))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            HStack(alignment: .center, spacing: 14) {
                ProgressRing(progress: usage.primaryFraction, lineWidth: 8, size: 72)
                VStack(alignment: .leading, spacing: 8) {
                    if usage.windows.isEmpty {
                        UsageBar(title: L10n.t("Использовано", "Used"), fraction: usage.primaryFraction)
                    } else {
                        ForEach(usage.windows.prefix(3)) { window in
                            UsageBar(title: windowLabel(window), fraction: window.fraction)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func windowLabel(_ window: UsageWindow) -> String {
        switch window.label {
        case "Auto": return "Auto"
        case "API": return "API"
        default: return window.label
        }
    }
}
