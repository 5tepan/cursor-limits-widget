import Darwin
import Foundation

/// Canonical paths for credentials and Application Support (host + widget).
enum AppPaths {
    static let directoryName = "CursorLimits"
    static let widgetBundleID = "com.local.CursorLimits.widget"

    /// Real macOS user home (not a sandbox container home).
    static var realHomeURL: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    static var applicationSupportDirectoryURL: URL {
        realHomeURL
            .appendingPathComponent("Library/Application Support/\(directoryName)", isDirectory: true)
    }

    static var widgetContainerDirectoryURL: URL {
        realHomeURL
            .appendingPathComponent(
                "Library/Containers/\(widgetBundleID)/Data/Library/Application Support/\(directoryName)",
                isDirectory: true
            )
    }

    /// Inside the widget process this is the container home; in the host it matches real home.
    static var processApplicationSupportDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(directoryName)", isDirectory: true)
    }

    static var cursorStateDatabaseURL: URL {
        realHomeURL
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }
}
