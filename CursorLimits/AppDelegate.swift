import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Single shared model — created before scenes so deep links are not dropped.
    let model: AppModel

    override init() {
        model = AppModel()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.notchPanel.sync(model: model)
    }
}
