import AppKit
import SwiftUI
import WidgetKit

@main
struct CursorLimitsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: appDelegate.model)
                .onOpenURL { url in
                    DeepLinkRouter.handle(url, model: appDelegate.model)
                }
        } label: {
            MenuBarLabel(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 5) {
            MenuBarGlyph(fraction: model.menuBarFraction)
            Text(model.menuBarTitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: AppSnapshot = .empty
    @Published var preferences: AppPreferences = .default
    @Published var isRefreshing = false
    @Published var lastError: String?
    @Published var language: LanguagePreference = LanguageStore.preference
    @Published var copilotDeviceCode: String?
    @Published var copilotVerifyURL: URL?
    @Published var isConnectingCopilot = false

    private var timer: Timer?
    private var prefsObserver: NSObjectProtocol?
    /// First refresh may run discovery only when `didCompleteDiscovery` is false.
    private var pendingLaunchDiscovery = true
    /// Settings → Rescan: force discovery once even after completion.
    private var forceDiscovery = false
    /// Coalesce overlapping refresh requests (timer + button + deep link).
    private var refreshAgain = false

    var menuBarFraction: Double? {
        guard let primary = snapshot.primary, primary.status == .ok else { return nil }
        return primary.primaryFraction
    }

    var menuBarTitle: String {
        guard let primary = snapshot.primary, primary.status == .ok else {
            return "Limits"
        }
        let reset = primary.windows.compactMap(\.resetsAt).max()
        return Formatters.compactMenuBarTitle(
            fraction: primary.primaryFraction,
            resetAt: reset,
            includeReset: preferences.compactMenuBarTitle
        )
    }

    init() {
        BundleIdentity.migrateLegacyDataIfNeeded()
        snapshot = AppSnapshotStore.load() ?? .empty
        preferences = AppPreferencesStore.load()
        language = LanguageStore.preference

        startTimer()
        prefsObserver = NotificationCenter.default.addObserver(
            forName: AppPreferencesStore.changeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.preferences = AppPreferencesStore.load()
                self?.language = LanguageStore.preference
            }
        }
        Task { await refresh() }
    }

    deinit {
        if let prefsObserver {
            NotificationCenter.default.removeObserver(prefsObserver)
        }
    }

    func setLanguage(_ value: LanguagePreference) {
        language = value
        LanguageStore.preference = value
        preferences = AppPreferencesStore.load()
    }

    func setProviderEnabled(_ id: ProviderID, enabled: Bool) {
        AppPreferencesStore.update { prefs in
            if enabled {
                if !prefs.enabledProviderIDs.contains(id) {
                    prefs.enabledProviderIDs.append(id)
                }
            } else {
                prefs.enabledProviderIDs.removeAll { $0 == id }
                if prefs.enabledProviderIDs.isEmpty {
                    prefs.enabledProviderIDs = [.cursor]
                }
                if prefs.primaryProviderID == id {
                    prefs.primaryProviderID = prefs.enabledProviderIDs[0]
                }
            }
        }
        preferences = AppPreferencesStore.load()
        Task { await refresh() }
    }

    /// Manual pick — locks primary until user chooses Auto again.
    func setPrimaryProvider(_ id: ProviderID) {
        AppPreferencesStore.update { prefs in
            prefs.primarySelectionMode = .manual
            prefs.primaryProviderID = id
            if !prefs.enabledProviderIDs.contains(id) {
                prefs.enabledProviderIDs.append(id)
            }
        }
        preferences = AppPreferencesStore.load()
        applyPrimaryToSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
        objectWillChange.send()
    }

    func setPrimaryAutomatic() {
        AppPreferencesStore.update { $0.primarySelectionMode = .automatic }
        preferences = AppPreferencesStore.load()
        applyAutomaticPrimary(from: snapshot.providers)
        applyPrimaryToSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
        objectWillChange.send()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    /// Re-run first-launch discovery: enable all, prune auth-missing, keep user prefs afterwards.
    func rediscoverProviders() async {
        forceDiscovery = true
        await refresh()
    }

    func refresh() async {
        if isRefreshing {
            refreshAgain = true
            return
        }
        isRefreshing = true
        defer {
            isRefreshing = false
            if refreshAgain {
                refreshAgain = false
                Task { await refresh() }
            }
        }

        preferences = AppPreferencesStore.load()
        let discovery = forceDiscovery
            || (pendingLaunchDiscovery && !preferences.didCompleteDiscovery)
        pendingLaunchDiscovery = false
        forceDiscovery = false

        if discovery {
            AppPreferencesStore.update { prefs in
                prefs.enabledProviderIDs = ProviderID.allCases
            }
            preferences = AppPreferencesStore.load()
        }

        var next = await MultiProviderRefresher.refresh(preferences: preferences)

        if discovery {
            pruneAfterDiscovery(snapshot: next)
            AppPreferencesStore.update { prefs in
                prefs.didCompleteDiscovery = true
            }
            preferences = AppPreferencesStore.load()
            let enabled = Set(preferences.enabledProviderIDs)
            next.providers = next.providers.filter { enabled.contains($0.providerID) }
            next.enabledProviderIDs = preferences.enabledProviderIDs
        }

        if preferences.primarySelectionMode == .automatic {
            applyAutomaticPrimary(from: next.providers)
            preferences = AppPreferencesStore.load()
        }

        next.primaryProviderID = preferences.primaryProviderID
        next.enabledProviderIDs = preferences.enabledProviderIDs
        next.providers = orderedProviders(next.providers, primary: preferences.primaryProviderID)

        snapshot = next
        lastError = next.providers.first(where: { $0.status == .error })?.errorMessage
            ?? next.primary.flatMap { $0.status == .ok ? nil : $0.errorMessage }

        do {
            try AppSnapshotStore.save(next)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            lastError = error.localizedDescription
        }

        await UsageAlertNotifier.evaluate(snapshot: next, preferences: preferences)
    }

    func setAlertsEnabled(_ enabled: Bool) {
        AppPreferencesStore.update { $0.alertsEnabled = enabled }
        preferences = AppPreferencesStore.load()
        if enabled {
            Task { await UsageAlertNotifier.evaluate(snapshot: snapshot, preferences: preferences) }
        }
    }

    func setQuietHoursEnabled(_ enabled: Bool) {
        AppPreferencesStore.update { $0.quietHoursEnabled = enabled }
        preferences = AppPreferencesStore.load()
    }

    func setQuietHours(start: Int, end: Int) {
        AppPreferencesStore.update {
            $0.quietHoursStartHour = start
            $0.quietHoursEndHour = end
        }
        preferences = AppPreferencesStore.load()
    }

    func setCompactMenuBarTitle(_ enabled: Bool) {
        AppPreferencesStore.update { $0.compactMenuBarTitle = enabled }
        preferences = AppPreferencesStore.load()
        objectWillChange.send()
    }

    func connectCopilot() async {
        isConnectingCopilot = true
        defer { isConnectingCopilot = false }
        do {
            let code = try await GitHubDeviceFlow.requestDeviceCode()
            copilotDeviceCode = code.user_code
            copilotVerifyURL = URL(string: code.verification_uri)
            if let url = copilotVerifyURL {
                NSWorkspace.shared.open(url)
            }
            _ = try await GitHubDeviceFlow.pollAccessToken(
                deviceCode: code.device_code,
                interval: code.interval
            )
            copilotDeviceCode = nil
            await refresh()
        } catch {
            lastError = error.localizedDescription
            copilotDeviceCode = nil
        }
    }

    // MARK: - Discovery / primary helpers

    private func pruneAfterDiscovery(snapshot: AppSnapshot) {
        let keep = snapshot.providers
            .filter { $0.status == .ok || $0.status == .error }
            .map(\.providerID)
        AppPreferencesStore.update { prefs in
            prefs.enabledProviderIDs = keep.isEmpty ? [.cursor] : keep
            if !prefs.enabledProviderIDs.contains(prefs.primaryProviderID) {
                prefs.primaryProviderID = prefs.enabledProviderIDs[0]
            }
        }
    }

    private func applyAutomaticPrimary(from providers: [ProviderUsage]) {
        let id = AppPreferencesStore.automaticPrimary(
            from: providers,
            enabled: preferences.enabledProviderIDs
        )
        AppPreferencesStore.update { prefs in
            guard prefs.primarySelectionMode == .automatic else { return }
            prefs.primaryProviderID = id
        }
    }

    private func applyPrimaryToSnapshot() {
        var next = snapshot
        next.primaryProviderID = preferences.primaryProviderID
        next.enabledProviderIDs = preferences.enabledProviderIDs
        next.providers = orderedProviders(next.providers, primary: preferences.primaryProviderID)
        snapshot = next
        try? AppSnapshotStore.save(next)
    }

    private func orderedProviders(_ providers: [ProviderUsage], primary: ProviderID) -> [ProviderUsage] {
        providers.sorted { a, b in
            if a.providerID == primary { return true }
            if b.providerID == primary { return false }
            let ia = ProviderID.allCases.firstIndex(of: a.providerID) ?? 0
            let ib = ProviderID.allCases.firstIndex(of: b.providerID) ?? 0
            return ia < ib
        }
    }
}
