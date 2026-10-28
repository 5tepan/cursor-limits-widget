import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case providers
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .providers: return L10n.providers
        case .general: return L10n.t("Общее", "General")
        }
    }

    var symbolName: String {
        switch self {
        case .providers: return "square.stack.3d.up"
        case .general: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var tab: SettingsTab = .providers
    @State private var launchAtLogin = AccountConnection.isLaunchAtLoginEnabled

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 560, height: 440)
        .id(model.language)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.appName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 8)

            ForEach(SettingsTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    Label(item.title, systemImage: item.symbolName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(tab == item ? Color.accentColor.opacity(0.14) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    tab == item ? Color.accentColor.opacity(0.35) : .clear,
                                    lineWidth: 1
                                )
                        )
                        .foregroundStyle(tab == item ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Text(L10n.privacyNote)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .padding(12)
        .frame(width: 168)
        .background(Color.primary.opacity(0.03))
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .providers:
            providersPane
        case .general:
            generalPane
        }
    }

    private var providersPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsHeader(
                    title: L10n.providers,
                    subtitle: L10n.t(
                        "Включите сервисы. Основной — первый в меню-баре и на виджете.",
                        "Enable services. Primary is first in the menu bar and widget."
                    )
                )

                primaryPicker

                VStack(spacing: 8) {
                    ForEach(ProviderID.allCases) { id in
                        ProviderSettingsRow(
                            id: id,
                            usage: model.snapshot.providers.first { $0.providerID == id },
                            isEnabled: model.preferences.enabledProviderIDs.contains(id),
                            isPrimary: model.preferences.primaryProviderID == id,
                            onToggle: { model.setProviderEnabled(id, enabled: $0) },
                            onMakePrimary: { model.setPrimaryProvider(id) }
                        )
                    }
                }

                rediscoverBlock

                if model.preferences.enabledProviderIDs.contains(.copilot) {
                    copilotBlock
                }
            }
            .padding(20)
        }
    }

    private var rediscoverBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.rediscoverProvidersHint)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await model.rediscoverProviders() }
            } label: {
                Label(L10n.rediscoverProviders, systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(model.isRefreshing)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var primaryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.primaryProvider)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: {
                    model.preferences.primarySelectionMode == .automatic
                        ? "automatic"
                        : model.preferences.primaryProviderID.rawValue
                },
                set: { value in
                    if value == "automatic" {
                        model.setPrimaryAutomatic()
                    } else if let id = ProviderID(rawValue: value) {
                        model.setPrimaryProvider(id)
                    }
                }
            )) {
                Text(L10n.primaryAutomatic).tag("automatic")
                ForEach(model.preferences.enabledProviderIDs, id: \.self) { id in
                    Text(id.displayName).tag(id.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var copilotBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GitHub Copilot")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        CopilotUsageProvider.loadGitHubToken() != nil
                            ? L10n.signedIn
                            : L10n.t("Не подключён", "Not connected")
                    )
                    .font(.system(size: 13, weight: .medium))

                    if let code = model.copilotDeviceCode {
                        Text("\(L10n.githubUserCode): \(code)")
                            .font(.system(size: 13, design: .monospaced).weight(.semibold))
                        Text(L10n.waitingGitHub)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L10n.t(
                            "gh auth login или device flow ниже",
                            "Use gh auth login or the device flow below"
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Task { await model.connectCopilot() }
                } label: {
                    if model.isConnectingCopilot {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text(L10n.connectGitHub)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.isConnectingCopilot)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
    }

    private var generalPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsHeader(
                    title: L10n.t("Общее", "General"),
                    subtitle: L10n.t(
                        "Язык, вырез, автозапуск и служебные действия.",
                        "Language, notch, launch at login, and utilities."
                    )
                )

                settingsGroup(title: L10n.language) {
                    HStack(spacing: 8) {
                        ForEach(LanguagePreference.allCases) { option in
                            LanguageOptionButton(
                                option: option,
                                isSelected: model.language == option
                            ) {
                                model.setLanguage(option)
                            }
                        }
                    }
                }

                settingsGroup(title: L10n.notchSection) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(L10n.notchPanelEnabled, isOn: Binding(
                            get: { model.preferences.notchPanelEnabled },
                            set: { model.setNotchPanelEnabled($0) }
                        ))
                        .toggleStyle(.switch)

                        Text(L10n.notchPanelHint)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                settingsGroup(title: L10n.status) {
                    VStack(spacing: 8) {
                        statusLine(
                            L10n.cursorSession,
                            AccountConnection.hasLocalSession ? L10n.signedIn : L10n.notSignedIn,
                            ok: AccountConnection.hasLocalSession
                        )
                        if let primary = model.snapshot.primary {
                            statusLine(
                                L10n.primaryProvider,
                                "\(primary.providerID.displayName) · \(primary.planName)",
                                ok: primary.status == .ok
                            )
                            if let email = primary.email {
                                statusLine("Email", email, ok: true)
                            }
                        }
                    }
                }

                settingsGroup(title: L10n.alertsSection) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(L10n.alertsEnabled, isOn: Binding(
                            get: { model.preferences.alertsEnabled },
                            set: { model.setAlertsEnabled($0) }
                        ))
                        .toggleStyle(.switch)

                        Text(L10n.alertsHint)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Toggle(L10n.quietHours, isOn: Binding(
                            get: { model.preferences.quietHoursEnabled },
                            set: { model.setQuietHoursEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .disabled(!model.preferences.alertsEnabled)

                        if model.preferences.quietHoursEnabled {
                            Text(L10n.quietHoursHint)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Picker(L10n.t("С", "From"), selection: Binding(
                                    get: { model.preferences.quietHoursStartHour },
                                    set: { model.setQuietHours(start: $0, end: model.preferences.quietHoursEndHour) }
                                )) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(String(format: "%02d:00", hour)).tag(hour)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 90)

                                Text("→")
                                    .foregroundStyle(.secondary)

                                Picker(L10n.t("До", "To"), selection: Binding(
                                    get: { model.preferences.quietHoursEndHour },
                                    set: { model.setQuietHours(start: model.preferences.quietHoursStartHour, end: $0) }
                                )) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(String(format: "%02d:00", hour)).tag(hour)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 90)
                            }
                            .disabled(!model.preferences.alertsEnabled)
                        }

                        Toggle(L10n.compactMenuBarTitle, isOn: Binding(
                            get: { model.preferences.compactMenuBarTitle },
                            set: { model.setCompactMenuBarTitle($0) }
                        ))
                        .toggleStyle(.switch)
                    }
                }

                settingsGroup(title: L10n.updatesSection) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.installedVersionLabel(AppUpdateChecker.installedVersion))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Toggle(L10n.automaticUpdateChecks, isOn: Binding(
                            get: { model.preferences.automaticUpdateChecks },
                            set: { model.setAutomaticUpdateChecks($0) }
                        ))
                        .toggleStyle(.switch)

                        if let update = model.availableUpdate {
                            Text(L10n.updateAvailable(update.version))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        } else if let message = model.updateStatusMessage {
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Button {
                                Task { await model.checkForUpdates(automatic: false) }
                            } label: {
                                if model.isCheckingForUpdate {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.horizontal, 6)
                                } else {
                                    Text(L10n.checkForUpdates)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(model.isCheckingForUpdate)

                            if model.availableUpdate != nil {
                                Button(L10n.downloadUpdate) {
                                    model.openUpdateDownload()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                settingsGroup(title: L10n.actions) {
                    Toggle(L10n.launchAtLogin, isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, enabled in
                            do {
                                try AccountConnection.setLaunchAtLogin(enabled)
                            } catch {
                                launchAtLogin = AccountConnection.isLaunchAtLoginEnabled
                                model.lastError = error.localizedDescription
                            }
                        }

                    HStack(spacing: 8) {
                        Button(L10n.refreshNow) {
                            Task { await model.refresh() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(L10n.checkConnection) {
                            Task { await model.refresh() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if AccountConnection.isCursorInstalled {
                            Button(L10n.openCursor, action: AccountConnection.openCursor)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        } else {
                            Button(L10n.downloadCursor, action: AccountConnection.openCursorDownload)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }

                        Button(L10n.openDataFolder) {
                            try? SnapshotStore.ensureDirectory()
                            NSWorkspace.shared.open(SnapshotStore.directoryURL)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.connectSafeNote)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.widgetHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }

    private func settingsHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func statusLine(_ title: String, _ value: String, ok: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ok ? Color.primary : Color.orange)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct ProviderSettingsRow: View {
    let id: ProviderID
    let usage: ProviderUsage?
    let isEnabled: Bool
    let isPrimary: Bool
    let onToggle: (Bool) -> Void
    let onMakePrimary: () -> Void
    @State private var showDiagnostics = false

    private var hasErrorDetails: Bool {
        isEnabled && usage?.status == .error
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: id.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(id.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if hasErrorDetails {
                Button(L10n.errorDetails) {
                    showDiagnostics = true
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Button(action: onMakePrimary) {
                Image(systemName: isPrimary ? "star.fill" : "star")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isPrimary ? Color.orange : Color.secondary.opacity(0.55))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .help(L10n.primaryProvider)
            .opacity(isEnabled ? 1 : 0.35)

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: onToggle
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(isEnabled ? 0.05 : 0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isPrimary && isEnabled ? Color.orange.opacity(0.35) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .opacity(isEnabled ? 1 : 0.72)
        .sheet(isPresented: $showDiagnostics) {
            ProviderDiagnosticsSheet(providerID: id)
        }
    }

    private var statusText: String {
        guard let usage else {
            return isEnabled ? L10n.noDataTitle : L10n.t("Выключен", "Off")
        }
        return ProviderErrorCopy.shortStatus(for: usage, enabled: isEnabled)
    }

    private var statusColor: Color {
        guard isEnabled, let usage else { return .secondary }
        switch usage.status {
        case .ok: return .secondary
        case .authMissing, .missing: return .orange.opacity(0.9)
        case .error: return .red.opacity(0.85)
        }
    }
}

private struct ProviderDiagnosticsSheet: View {
    let providerID: ProviderID
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ProviderDiagnosticEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(providerID.displayName) · \(L10n.errorLogTitle)")
                        .font(.headline)
                    Text(L10n.errorLogSafeNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.clearErrorLog) {
                    ProviderDiagnosticsStore.clear(provider: providerID)
                    reload()
                }
                .disabled(entries.isEmpty)
                Button(L10n.t("Закрыть", "Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            if entries.isEmpty {
                Text(L10n.noErrorLog)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(entry.summary)
                                        .font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    Text(Formatters.timeAgo(entry.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Text(entry.detail)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button(L10n.copyErrorLog) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(
                                        SecretRedactor.redact("\(entry.summary)\n\n\(entry.detail)"),
                                        forType: .string
                                    )
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 520, height: 420)
        .onAppear(perform: reload)
    }

    private func reload() {
        entries = ProviderDiagnosticsStore.entries(for: providerID)
    }
}
