import Foundation

enum SnapshotStore {
    static let directoryName = AppPaths.directoryName
    static let fileName = "snapshot.json"
    static let widgetBundleID = AppPaths.widgetBundleID

    static var realHomeURL: URL { AppPaths.realHomeURL }
    static var applicationSupportDirectoryURL: URL { AppPaths.applicationSupportDirectoryURL }
    static var widgetContainerDirectoryURL: URL { AppPaths.widgetContainerDirectoryURL }
    static var processApplicationSupportDirectoryURL: URL { AppPaths.processApplicationSupportDirectoryURL }

    static var directoryURL: URL { applicationSupportDirectoryURL }

    static var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    static func ensureDirectory() throws {
        for dir in writeDirectories() {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Legacy Cursor-only snapshot — read for one-shot migration into `app-snapshot.json`.
    static func load() -> UsageSnapshot? {
        for url in readURLs() {
            if let snapshot = decode(from: url) {
                return snapshot
            }
        }
        return nil
    }

    private static func writeDirectories() -> [URL] {
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
