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

    private var timer: Timer?

    var menuBarTitle: String {
        guard snapshot.status == .ok else { return "Cursor" }
        let fraction = snapshot.totalPercentUsed ?? snapshot.apiPercentUsed ?? snapshot.autoPercentUsed
        return Formatters.percent(fraction)
    }

    init() {
        startTimer()
        Task { await refresh() }
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
