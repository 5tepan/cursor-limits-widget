import Foundation
import WidgetKit

struct AppPreferences: Codable, Equatable, Sendable {
    var language: LanguagePreference
    var enabledProviderIDs: [ProviderID]
    var primaryProviderID: ProviderID

    static var `default`: AppPreferences {
        AppPreferences(
            language: .system,
            enabledProviderIDs: AppPreferencesStore.defaultEnabled,
            primaryProviderID: .cursor
        )
    }
}

enum AppPreferencesStore {
    static let defaultEnabled: [ProviderID] = [
        .cursor, .claude, .codex, .ollamaCloud, .opencodeGo, .copilot
    ]
    private static let fileName = "preferences.json"
    private static let didChange = Notification.Name("CursorLimitsPreferencesDidChange")

    static var changeNotification: Notification.Name { didChange }

    private static var candidateURLs: [URL] {
        var seen = Set<String>()
        var urls: [URL] = []
        for dir in [
            SnapshotStore.processApplicationSupportDirectoryURL,
            SnapshotStore.widgetContainerDirectoryURL,
            SnapshotStore.applicationSupportDirectoryURL
        ] {
            let url = dir.appendingPathComponent(fileName)
            if seen.insert(url.path).inserted {
                urls.append(url)
            }
        }
        return urls
    }

    static func load() -> AppPreferences {
        for url in candidateURLs {
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url)
            else { continue }

            // New format
            if let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) {
                return normalized(prefs)
            }
            // Legacy language-only format
            if let legacy = try? JSONDecoder().decode(LegacyLanguageFile.self, from: data),
               let language = LanguagePreference(rawValue: legacy.language)
            {
                var prefs = AppPreferences.default
                prefs.language = language
                return prefs
            }
        }
        return .default
    }

    static func save(_ prefs: AppPreferences) {
        let value = normalized(prefs)
        try? SnapshotStore.ensureDirectory()
        guard let data = try? JSONEncoder().encode(value) else { return }
        for url in candidateURLs {
            try? data.write(to: url, options: .atomic)
        }
        NotificationCenter.default.post(name: didChange, object: nil)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func update(_ mutate: (inout AppPreferences) -> Void) {
        var prefs = load()
        mutate(&prefs)
        save(prefs)
    }

    private static func normalized(_ prefs: AppPreferences) -> AppPreferences {
        var copy = prefs
        if copy.enabledProviderIDs.isEmpty {
            copy.enabledProviderIDs = defaultEnabled
        }
        // Keep unique order
        var seen = Set<ProviderID>()
        copy.enabledProviderIDs = copy.enabledProviderIDs.filter { seen.insert($0).inserted }
        if !copy.enabledProviderIDs.contains(copy.primaryProviderID) {
            copy.primaryProviderID = copy.enabledProviderIDs.first ?? .cursor
        }
        return copy
    }

    private struct LegacyLanguageFile: Codable {
        var language: String
    }
}
