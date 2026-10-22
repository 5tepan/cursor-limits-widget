import Foundation

/// Stable reverse-DNS IDs. Changing these is a new app identity for Launch Services / Keychain ACL.
enum BundleIdentity {
    static let host = "com.5tepan.cursorlimits"
    static let widget = "com.5tepan.cursorlimits.widget"
    static let tests = "com.5tepan.cursorlimits.tests"

    static let legacyHost = "com.local.CursorLimits"
    static let legacyWidget = "com.local.CursorLimits.widget"

    private static let migratedFlagName = "bundle-id-migrated-v1"

    /// Copy widget-container snapshots/prefs from the old `com.local.*` container if needed.
    /// Application Support/`CursorLimits` is unchanged (not bundle-id keyed).
    static func migrateLegacyDataIfNeeded() {
        let flag = AppPaths.applicationSupportDirectoryURL.appendingPathComponent(migratedFlagName)
        if FileManager.default.fileExists(atPath: flag.path) { return }

        let fm = FileManager.default
        let legacyDir = AppPaths.realHomeURL.appendingPathComponent(
            "Library/Containers/\(legacyWidget)/Data/Library/Application Support/\(AppPaths.directoryName)",
            isDirectory: true
        )
        let newDir = AppPaths.widgetContainerDirectoryURL

        if fm.fileExists(atPath: legacyDir.path) {
            try? fm.createDirectory(at: newDir, withIntermediateDirectories: true)
            let names = ["app-snapshot.json", "preferences.json", "snapshot.json", "diagnostics.json", "alert-state.json"]
            for name in names {
                let src = legacyDir.appendingPathComponent(name)
                let dst = newDir.appendingPathComponent(name)
                guard fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) else { continue }
                try? fm.copyItem(at: src, to: dst)
            }
        }

        try? fm.createDirectory(
            at: AppPaths.applicationSupportDirectoryURL,
            withIntermediateDirectories: true
        )
        try? "ok".data(using: .utf8)?.write(to: flag, options: .atomic)
    }
}
