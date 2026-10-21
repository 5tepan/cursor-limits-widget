import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if model.snapshot.status != .ok {
                OnboardingView(model: model)
            } else {
                usageSection
                if let tokens = model.snapshot.tokenStats {
                    Divider()
                    tokensSection(tokens)
                }
                if !model.snapshot.topModels.isEmpty {
                    Divider()
                    modelsSection
                }
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.snapshot.status == .ok ? model.snapshot.planName : L10n.appName)
                    .font(.headline)
                if model.snapshot.status == .ok, let email = model.snapshot.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(model.isRefreshing)
            .help(L10n.refresh)
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ProgressRing(
                    progress: model.snapshot.totalPercentUsed ?? model.snapshot.apiPercentUsed,
                    lineWidth: 9,
                    size: 72
                )
                VStack(alignment: .leading, spacing: 8) {
                    UsageBar(title: "Auto", fraction: model.snapshot.autoPercentUsed)
                    UsageBar(title: "API", fraction: model.snapshot.apiPercentUsed)
                }
            }

            HStack {
                labeled(L10n.resetIn, Formatters.daysUntilReset(model.snapshot.billingCycleEnd))
                Spacer()
                labeled(
                    L10n.spent,
                    Formatters.spendDisplay(
                        totalSpend: model.snapshot.totalSpend,
                        includedSpend: model.snapshot.includedSpend
                    )
                )
                if model.snapshot.onDemandEnabled {
                    Spacer()
                    labeled(L10n.onDemand, Formatters.dollars(fromCents: model.snapshot.onDemandUsedCents))
                }
            }
            .font(.caption)
        }
    }

    private func tokensSection(_ tokens: TokenStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tokensCycle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                labeled("In", Formatters.compactNumber(tokens.inputTokens))
                labeled("Out", Formatters.compactNumber(tokens.outputTokens))
                labeled("Cache", Formatters.compactNumber(tokens.cacheReadTokens + tokens.cacheWriteTokens))
                labeled("Req", "\(tokens.eventCount)")
            }
        }
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.topModels)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(model.snapshot.topModels.prefix(4)) { model in
                HStack {
                    Text(Formatters.shortModelName(model.name))
                        .font(.caption.monospaced())
                        .lineLimit(1)
                    Spacer()
                    Text("\(model.requests)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(footerText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
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
        if model.snapshot.status != .ok {
            return L10n.privacyNote
        }
        return "\(L10n.updated) \(Formatters.timeAgo(model.snapshot.fetchedAt))"
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = AccountConnection.isLaunchAtLoginEnabled

    var body: some View {
        Form {
            Section(L10n.status) {
                LabeledContent(L10n.plan, value: model.snapshot.planName)
                LabeledContent("Email", value: model.snapshot.email ?? "—")
                LabeledContent(
                    L10n.t("Сессия Cursor", "Cursor session"),
                    value: AccountConnection.hasLocalSession ? L10n.signedIn : L10n.notSignedIn
                )
            }

            Section(L10n.howToConnect) {
                Text(L10n.connectSafeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if AccountConnection.isCursorInstalled {
                    Button(L10n.openCursor, action: AccountConnection.openCursor)
                } else {
                    Button(L10n.downloadCursor, action: AccountConnection.openCursorDownload)
                }
                Button(L10n.checkConnection) {
                    Task { await model.refresh() }
                }
            }

            Section(L10n.actions) {
                Toggle(L10n.launchAtLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try AccountConnection.setLaunchAtLogin(enabled)
                        } catch {
                            launchAtLogin = AccountConnection.isLaunchAtLoginEnabled
                            model.lastError = error.localizedDescription
                        }
                    }
                Button(L10n.refreshNow) {
                    Task { await model.refresh() }
                }
                Button(L10n.openDataFolder) {
                    try? SnapshotStore.ensureDirectory()
                    NSWorkspace.shared.open(SnapshotStore.directoryURL)
                }
            }

            Text(L10n.widgetHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L10n.privacyNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 440, height: 420)
    }
}
