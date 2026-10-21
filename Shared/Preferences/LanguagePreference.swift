import Foundation
import WidgetKit

enum LanguagePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case russian

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .system: return L10n.t("Системный", "System")
        case .english: return "English"
        case .russian: return "Русский"
        }
    }

    /// Compact badge on the collapsed language row.
    var currentLabel: String {
        switch self {
        case .system: return L10n.t("Авто", "Auto")
        case .english: return "EN"
        case .russian: return "RU"
        }
    }

    var shortTitle: String {
        switch self {
        case .system: return "Auto"
        case .english: return "EN"
        case .russian: return "RU"
        }
    }

    var optionTitle: String {
        switch self {
        case .system: return L10n.t("Авто", "Auto")
        case .english: return "English"
        case .russian: return "Русский"
        }
    }

    var optionSubtitle: String {
        switch self {
        case .system: return L10n.t("как в macOS", "match macOS")
        case .english: return "EN"
        case .russian: return "RU"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "laptopcomputer"
        case .english: return "character.textbox"
        case .russian: return "character.book.closed"
        }
    }
}

enum LanguageStore {
    private static let fileName = "preferences.json"
    private static let didChange = Notification.Name("CursorLimitsLanguageDidChange")

    private struct FilePayload: Codable {
        var language: String
    }

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

    static var preference: LanguagePreference {
        get { load() }
        set {
            guard newValue != load() else { return }
            save(newValue)
            NotificationCenter.default.post(name: didChange, object: newValue.rawValue)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static var isRussian: Bool {
        switch preference {
        case .russian:
            return true
        case .english:
            return false
        case .system:
            return Locale.current.language.languageCode?.identifier == "ru"
        }
    }

    static var changeNotification: Notification.Name { didChange }

    private static func load() -> LanguagePreference {
        for url in candidateURLs {
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let payload = try? JSONDecoder().decode(FilePayload.self, from: data),
                  let value = LanguagePreference(rawValue: payload.language)
            else { continue }
            return value
        }
        return .system
    }

    private static func save(_ value: LanguagePreference) {
        try? SnapshotStore.ensureDirectory()
        let payload = FilePayload(language: value.rawValue)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        for url in candidateURLs {
            try? data.write(to: url, options: .atomic)
        }
    }
}
