import Foundation

/// Checks GitHub Releases for a newer app version (no Sparkle — works with ad-hoc CI zips).
enum AppUpdateChecker {
    static let githubOwner = "5tepan"
    static let githubRepo = "cursor-limits-widget"

    struct ReleaseInfo: Equatable, Sendable {
        var tagName: String
        var version: String
        var htmlURL: URL
        var zipURL: URL?
        var publishedAt: Date?
    }

    static var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? "0"
    }

    static func latestRelease() async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CursorLimits/\(installedVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.network
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UpdateError.http(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let version = normalizeVersion(decoded.tag_name)
        guard let html = URL(string: decoded.html_url) else {
            throw UpdateError.invalidResponse
        }
        let zip = decoded.assets
            .first { $0.name.lowercased().hasSuffix("-macos.zip") || $0.name.lowercased().hasSuffix(".zip") }
            .flatMap { URL(string: $0.browser_download_url) }

        return ReleaseInfo(
            tagName: decoded.tag_name,
            version: version,
            htmlURL: html,
            zipURL: zip,
            publishedAt: ISO8601DateFormatter().date(from: decoded.published_at ?? "")
        )
    }

    /// Returns release only when remote version is newer than the installed build.
    static func availableUpdate() async throws -> ReleaseInfo? {
        let latest = try await latestRelease()
        guard isVersion(latest.version, newerThan: installedVersion) else { return nil }
        return latest
    }

    static func normalizeVersion(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("v") {
            s = String(s.dropFirst())
        }
        return s
    }

    /// Semver-ish compare: `1.2.0` > `1.1.9`. Non-numeric segments compare lexicographically.
    static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let a = components(normalizeVersion(remote))
        let b = components(normalizeVersion(local))
        let count = max(a.count, b.count)
        for i in 0..<count {
            let lhs = i < a.count ? a[i] : 0
            let rhs = i < b.count ? b[i] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { part in
                let digits = part.prefix(while: { $0.isNumber })
                return Int(digits) ?? 0
            }
    }

    enum UpdateError: Error, LocalizedError {
        case network
        case http(Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .network: return "Network error"
            case .http(let code): return "HTTP \(code)"
            case .invalidResponse: return "Invalid response"
            }
        }
    }

    private struct GitHubRelease: Decodable {
        var tag_name: String
        var html_url: String
        var published_at: String?
        var assets: [Asset]

        struct Asset: Decodable {
            var name: String
            var browser_download_url: String
        }
    }
}

enum AppUpdateStateStore {
    private static let fileName = "update-state.json"

    struct State: Codable, Equatable {
        var lastNotifiedVersion: String?
        var lastCheckedAt: Date?
    }

    private static var fileURL: URL {
        AppPaths.applicationSupportDirectoryURL.appendingPathComponent(fileName)
    }

    static func load() -> State {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return State() }
        return state
    }

    static func save(_ state: State) {
        try? SnapshotStore.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
