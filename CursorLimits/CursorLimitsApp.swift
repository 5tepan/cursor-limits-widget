import AppKit
import SwiftUI
import WidgetKit

@main
struct CursorLimitsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            HStack(spacing: 5) {
                MenuBarGlyph(fraction: model.menuBarFraction)
                Text(model.menuBarTitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: AppSnapshot = AppSnapshotStore.load() ?? .empty
    @Published var preferences: AppPreferences = AppPreferencesStore.load()
    @Published var isRefreshing = false
    @Published var lastError: String?
    @Published var language: LanguagePreference = LanguageStore.preference
    @Published var copilotDeviceCode: String?
    @Published var copilotVerifyURL: URL?
    @Published var isConnectingCopilot = false

    private var timer: Timer?
    private var prefsObserver: NSObjectProtocol?
    /// First refresh of this process runs full provider discovery.
    private var pendingLaunchDiscovery = true

    var menuBarFraction: Double? {
        guard let primary = snapshot.primary, primary.status == .ok else { return nil }
        return primary.primaryFraction
    }

    var menuBarTitle: String {
        guard let primary = snapshot.primary, primary.status == .ok else {
            return "Limits"
        }
        return Formatters.percent(primary.primaryFraction)
    }

    init() {
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

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let discovery = pendingLaunchDiscovery
        if discovery {
            pendingLaunchDiscovery = false
            AppPreferencesStore.update { prefs in
                prefs.enabledProviderIDs = ProviderID.allCases
            }
            preferences = AppPreferencesStore.load()
        }

        var next = await MultiProviderRefresher.refresh(preferences: preferences)

        if discovery {
            pruneAfterDiscovery(snapshot: next)
            preferences = AppPreferencesStore.load()
            // Re-filter snapshot providers to enabled set for consistent UI
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
        // Stable order: primary first, then enabled order
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
            // Drop manual primary if it was pruned
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
