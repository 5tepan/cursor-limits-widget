import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let model else { return }
        for url in urls {
            Task { @MainActor in
                DeepLinkRouter.handle(url, model: model)
            }
        }
    }
}
