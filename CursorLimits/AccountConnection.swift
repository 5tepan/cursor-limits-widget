import AppKit
import Foundation
import ServiceManagement

enum AccountConnection {
    static let cursorBundleID = "com.todesktop.230313mzl4w4u92"
    static let cursorDownloadURL = URL(string: "https://cursor.com/download")!

    static var isCursorInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: cursorBundleID) != nil
            || FileManager.default.fileExists(atPath: "/Applications/Cursor.app")
    }

    static var hasLocalSession: Bool {
        // Count sealed tokens too — decrypt happens on refresh (may prompt Keychain).
        CursorCredentialsLoader.hasStoredToken()
    }

    static func openCursor() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: cursorBundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        let fallback = URL(fileURLWithPath: "/Applications/Cursor.app")
        if FileManager.default.fileExists(atPath: fallback.path) {
            NSWorkspace.shared.openApplication(at: fallback, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        NSWorkspace.shared.open(cursorDownloadURL)
    }

    static func openCursorDownload() {
        NSWorkspace.shared.open(cursorDownloadURL)
    }

    @discardableResult
    static func setLaunchAtLogin(_ enabled: Bool) throws -> Bool {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        return isLaunchAtLoginEnabled
    }

    static var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
