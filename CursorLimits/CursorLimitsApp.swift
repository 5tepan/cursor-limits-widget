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
                MenuBarGlyph(
                    fraction: model.snapshot.status == .ok
                        ? (model.snapshot.totalPercentUsed
                            ?? model.snapshot.apiPercentUsed
                            ?? model.snapshot.autoPercentUsed)
                        : nil
                )
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
    @Published var snapshot: UsageSnapshot = SnapshotStore.load() ?? .empty
    @Published var isRefreshing = false
    @Published var lastError: String?
    @Published var language: LanguagePreference = LanguageStore.preference

    private var timer: Timer?
    private var languageObserver: NSObjectProtocol?

    var menuBarTitle: String {
        guard snapshot.status == .ok else { return "Cursor" }
        let fraction = snapshot.totalPercentUsed ?? snapshot.apiPercentUsed ?? snapshot.autoPercentUsed
        return Formatters.percent(fraction)
    }

    init() {
        startTimer()
        languageObserver = NotificationCenter.default.addObserver(
            forName: LanguageStore.changeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.language = LanguageStore.preference
            }
        }
        Task { await refresh() }
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    func setLanguage(_ value: LanguagePreference) {
        language = value
        LanguageStore.preference = value
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

        let next = await UsageRefresher.refresh()
        snapshot = next
        lastError = next.status == .ok ? nil : next.errorMessage

        do {
            try SnapshotStore.save(next)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
