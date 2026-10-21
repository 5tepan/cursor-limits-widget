import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var languageExpanded = false
    @State private var expandedIDs: Set<String> = []
    @State private var didSeedExpanded = false

    private var providers: [ProviderUsage] {
        let enabled = Set(model.preferences.enabledProviderIDs)
        let primaryID = model.preferences.primaryProviderID
        let all = model.snapshot.providers.filter { enabled.contains($0.providerID) }
        // Primary first (snapshot usually already ordered)
        return all.sorted { a, b in
            if a.providerID == primaryID { return true }
            if b.providerID == primaryID { return false }
            return false
        }
    }

    private var hasAnyOK: Bool {
        providers.contains { $0.status == .ok }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !hasAnyOK {
                OnboardingView(model: model)
            } else {
                ForEach(providers) { usage in
                    ProviderCard(
                        usage: usage,
                        isPrimary: usage.providerID == model.preferences.primaryProviderID,
                        expanded: expandedIDs.contains(usage.providerID.rawValue),
                        onToggleExpanded: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                let key = usage.providerID.rawValue
                                if expandedIDs.contains(key) {
                                    expandedIDs.remove(key)
                                } else {
                                    expandedIDs.insert(key)
                                }
                            }
                        }
                    )
                }
            }

            Divider()
            languagePicker
            Divider()
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .frame(width: 360)
        .id(model.language)
        .onAppear { seedExpandedIfNeeded() }
        .onChange(of: model.snapshot.fetchedAt) { _, _ in
            seedExpandedIfNeeded(forceMissingOnly: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .cursorLimitsOpenSettings)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
    }

    private func seedExpandedIfNeeded(forceMissingOnly: Bool = false) {
        if !forceMissingOnly, didSeedExpanded { return }
        let keys = Set(providers.map(\.providerID.rawValue))
        if !didSeedExpanded {
            expandedIDs = keys
            didSeedExpanded = true
        } else {
            // Newly appeared providers start expanded
            expandedIDs.formUnion(keys.subtracting(expandedIDs))
        }
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    languageExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.language)
                        .font(.subheadline.weight(.medium))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(model.language.currentLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(languageExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if languageExpanded {
                HStack(spacing: 8) {
                    ForEach(LanguagePreference.allCases) { option in
                        LanguageOptionButton(
                            option: option,
                            isSelected: model.language == option
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                model.setLanguage(option)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("BrandIcon")
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.appName)
                    .font(.headline)
                    .lineLimit(1)
                if hasAnyOK {
                    Text(providers.map(\.providerID.displayName).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(model.isRefreshing)
            .help(L10n.refresh)
        }
    }

    private var footer: some View {
        HStack {
            Text(footerText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L10n.actions)
            Button(L10n.quit) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    private var footerText: String {
        if model.isRefreshing { return L10n.updating }
        if !hasAnyOK { return L10n.privacyNote }
        return "\(L10n.updated) \(Formatters.timeAgo(model.snapshot.fetchedAt))"
    }
}

struct ProviderCard: View {
    let usage: ProviderUsage
    let isPrimary: Bool
    let expanded: Bool
    let onToggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggleExpanded) {
                HStack(spacing: 6) {
                    Image(systemName: usage.providerID.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(usage.providerID.displayName)
                        .font(.subheadline.weight(.semibold))
                    if usage.planName != "—", !usage.planName.isEmpty {
                        Text("· \(usage.planName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                    Spacer(minLength: 0)
                    statusTrailing
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if usage.status == .ok {
                if expanded {
                    detailedBody
                } else {
                    compactBody
                }
            } else if expanded {
                Text(ProviderErrorCopy.shortStatus(for: usage, enabled: true))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var statusTrailing: some View {
        switch usage.status {
        case .ok:
            Text(Formatters.percent(usage.primaryFraction))
                .font(.caption.weight(.bold).monospacedDigit())
        case .authMissing:
            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .missing:
            Text("…")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(usage.windows.prefix(2)) { window in
                UsageBar(title: window.label, fraction: window.fraction)
            }
        }
    }

    private var detailedBody: some View {
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
