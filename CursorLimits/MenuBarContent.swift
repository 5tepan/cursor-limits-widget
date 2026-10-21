import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @State private var languageExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if model.snapshot.status != .ok {
                OnboardingView(model: model)
            } else {
                detailedUsageSection
            }

            Divider()
            languagePicker
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 360)
        .id(model.language)
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.20))
                    Text(headerTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
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

    private var headerTitle: String {
        if model.snapshot.status == .ok {
            return "Cursor · \(model.snapshot.planName)"
        }
        return L10n.appName
    }

    private var detailedUsageSection: some View {
        let snapshot = model.snapshot
        return VStack(alignment: .leading, spacing: 12) {
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

}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = AccountConnection.isLaunchAtLoginEnabled

    var body: some View {
        Form {
            Section(L10n.language) {
                Picker(L10n.language, selection: Binding(
                    get: { model.language },
                    set: { model.setLanguage($0) }
                )) {
                    Text(L10n.languageSystem).tag(LanguagePreference.system)
                    Text("English").tag(LanguagePreference.english)
                    Text("Русский").tag(LanguagePreference.russian)
                }
                .pickerStyle(.radioGroup)
            }

            Section(L10n.status) {
                LabeledContent(L10n.plan, value: model.snapshot.planName)
                LabeledContent("Email", value: model.snapshot.email ?? "—")
                LabeledContent(
                    L10n.cursorSession,
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
        .frame(width: 440, height: 460)
        .id(model.language)
    }
}
