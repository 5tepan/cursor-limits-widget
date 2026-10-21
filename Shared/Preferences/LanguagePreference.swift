import Foundation

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

/// Compatibility façade over AppPreferencesStore.language
enum LanguageStore {
    static var changeNotification: Notification.Name { AppPreferencesStore.changeNotification }

    static var preference: LanguagePreference {
        get { AppPreferencesStore.load().language }
        set {
            AppPreferencesStore.update { $0.language = newValue }
        }
    }

    static var isRussian: Bool {
        switch preference {
        case .russian: return true
        case .english: return false
        case .system:
            return Locale.current.language.languageCode?.identifier == "ru"
        }
    }
}
