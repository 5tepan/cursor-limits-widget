import Foundation
import WidgetKit

enum PrimarySelectionMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case manual
}

struct AppPreferences: Equatable, Sendable {
    var language: LanguagePreference
    var enabledProviderIDs: [ProviderID]
    var primaryProviderID: ProviderID
    var primarySelectionMode: PrimarySelectionMode
    /// First-launch (or manual rescan) discovery has finished — do not overwrite enables again.
    var didCompleteDiscovery: Bool

    static var `default`: AppPreferences {
        AppPreferences(
            language: .system,
            enabledProviderIDs: AppPreferencesStore.defaultEnabled,
            primaryProviderID: .cursor,
            primarySelectionMode: .automatic,
            didCompleteDiscovery: false
        )
    }
}

extension AppPreferences: Codable {
    enum CodingKeys: String, CodingKey {
        case language, enabledProviderIDs, primaryProviderID, primarySelectionMode, didCompleteDiscovery
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = try c.decodeIfPresent(LanguagePreference.self, forKey: .language) ?? .system
        enabledProviderIDs = try c.decodeIfPresent([ProviderID].self, forKey: .enabledProviderIDs)
            ?? AppPreferencesStore.defaultEnabled
        primaryProviderID = try c.decodeIfPresent(ProviderID.self, forKey: .primaryProviderID) ?? .cursor
        primarySelectionMode = try c.decodeIfPresent(PrimarySelectionMode.self, forKey: .primarySelectionMode)
            ?? .automatic
        // Existing installs already have a customized list — treat as discovered.
        didCompleteDiscovery = try c.decodeIfPresent(Bool.self, forKey: .didCompleteDiscovery) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(language, forKey: .language)
        try c.encode(enabledProviderIDs, forKey: .enabledProviderIDs)
        try c.encode(primaryProviderID, forKey: .primaryProviderID)
        try c.encode(primarySelectionMode, forKey: .primarySelectionMode)
        try c.encode(didCompleteDiscovery, forKey: .didCompleteDiscovery)
    }
}

enum AppPreferencesStore {
    static let defaultEnabled: [ProviderID] = ProviderID.allCases
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
            // Legacy without primarySelectionMode
            if let legacy = try? JSONDecoder().decode(LegacyPrefs.self, from: data) {
                var prefs = AppPreferences.default
                if let language = LanguagePreference(rawValue: legacy.language ?? "system") {
                    prefs.language = language
                }
                if let enabled = legacy.enabledProviderIDs, !enabled.isEmpty {
                    prefs.enabledProviderIDs = enabled.compactMap(ProviderID.init(rawValue:))
                }
                if let primary = legacy.primaryProviderID.flatMap(ProviderID.init(rawValue:)) {
                    prefs.primaryProviderID = primary
                }
                prefs.primarySelectionMode = .automatic
                prefs.didCompleteDiscovery = true
                return normalized(prefs)
            }
            // Language-only format
            if let legacy = try? JSONDecoder().decode(LegacyLanguageFile.self, from: data),
               let language = LanguagePreference(rawValue: legacy.language)
            {
                var prefs = AppPreferences.default
                prefs.language = language
                prefs.didCompleteDiscovery = true
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

    /// Pick primary among OK providers by highest usage fraction.
    static func automaticPrimary(from providers: [ProviderUsage], enabled: [ProviderID]) -> ProviderID {
        let enabledSet = Set(enabled)
        let ok = providers.filter { enabledSet.contains($0.providerID) && $0.status == .ok }
        guard !ok.isEmpty else {
            return enabled.first ?? .cursor
        }
        let order = Dictionary(uniqueKeysWithValues: ProviderID.allCases.enumerated().map { ($1, $0) })
        return ok.max { a, b in
            let fa = a.primaryFraction ?? -1
            let fb = b.primaryFraction ?? -1
            if fa != fb { return fa < fb }
            return (order[a.providerID] ?? 0) > (order[b.providerID] ?? 0)
        }!.providerID
    }

    private static func normalized(_ prefs: AppPreferences) -> AppPreferences {
        var copy = prefs
        if copy.enabledProviderIDs.isEmpty {
            copy.enabledProviderIDs = defaultEnabled
        }
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

    private struct LegacyPrefs: Codable {
        var language: String?
        var enabledProviderIDs: [String]?
        var primaryProviderID: String?
    }
}
