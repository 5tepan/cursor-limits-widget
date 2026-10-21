import Darwin
import Foundation

enum SnapshotStore {
    static let directoryName = "CursorLimits"
    static let fileName = "snapshot.json"
    static let widgetBundleID = "com.local.CursorLimits.widget"

    /// Real macOS user home (not a sandbox container).
    static var realHomeURL: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    /// Host app location (readable without sandbox).
    static var applicationSupportDirectoryURL: URL {
        realHomeURL
            .appendingPathComponent("Library/Application Support/\(directoryName)", isDirectory: true)
    }

    /// Widget sandbox container — host writes here so the widget can read without entitlements hacks.
    static var widgetContainerDirectoryURL: URL {
        realHomeURL
            .appendingPathComponent(
                "Library/Containers/\(widgetBundleID)/Data/Library/Application Support/\(directoryName)",
                isDirectory: true
            )
    }

    /// Inside the widget process this is the container home; in the host it is the real home.
    static var processApplicationSupportDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(directoryName)", isDirectory: true)
    }

    static var directoryURL: URL { applicationSupportDirectoryURL }

    static var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    static func ensureDirectory() throws {
        for dir in writeDirectories() {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func load() -> UsageSnapshot? {
        for url in readURLs() {
            if let snapshot = decode(from: url) {
                return snapshot
            }
        }
        return nil
    }

    static func save(_ snapshot: UsageSnapshot) throws {
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)

        var wrote = false
        var lastError: Error?
        for url in writeURLs() {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: .atomic)
                wrote = true
            } catch {
                lastError = error
            }
        }
        if !wrote, let lastError {
            throw lastError
        }
    }

    private static func writeDirectories() -> [URL] {
        // De-dupe while preserving order.
        var seen = Set<String>()
        var dirs: [URL] = []
        for dir in [
            applicationSupportDirectoryURL,
            widgetContainerDirectoryURL,
            processApplicationSupportDirectoryURL
        ] {
            let path = dir.path
            if seen.insert(path).inserted {
                dirs.append(dir)
            }
        }
        return dirs
    }

    private static func readURLs() -> [URL] {
        writeDirectories().map { $0.appendingPathComponent(fileName) }
    }

    private static func writeURLs() -> [URL] {
        readURLs()
    }

    private static func decode(from url: URL) -> UsageSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(UsageSnapshot.self, from: data)
        } catch {
            return nil
        }
    }
}
