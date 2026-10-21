import AppKit
import Foundation

/// `cursorlimits://` handoff for external UIs (e.g. a Cyclop Limits tab).
enum DeepLinkRouter {
    static let scheme = "cursorlimits"

    enum Action: String {
        case refresh
        case settings
    }

    @MainActor
    static func handle(_ url: URL, model: AppModel) {
        guard url.scheme?.lowercased() == scheme else { return }
        let host = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
            .lowercased()
        switch Action(rawValue: host) {
        case .refresh:
            Task { await model.refresh() }
        case .settings:
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .cursorLimitsOpenSettings, object: nil)
        case .none:
            break
        }
    }
}

extension Notification.Name {
    static let cursorLimitsOpenSettings = Notification.Name("CursorLimitsOpenSettings")
}
