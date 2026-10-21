import Foundation

/// App strings. Language follows `LanguageStore.preference` (System / English / Russian).
enum L10n {
    static var isRussian: Bool {
        LanguageStore.isRussian
    }

    static func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }

    // Menu / status
    static var appName: String { "Cursor Limits" }
    static var refresh: String { t("Обновить", "Refresh") }
    static var quit: String { t("Выход", "Quit") }
    static var updating: String { t("Обновление…", "Updating…") }
    static var updated: String { t("обновлено", "updated") }
    static var resetIn: String { t("Сброс через", "Resets in") }
    static var spent: String { t("Потрачено", "Spent") }
    static var onDemand: String { t("Сверх лимита", "On-demand") }
    static var tokensCycle: String { t("Токены за цикл", "Tokens this cycle") }
    static var topModels: String { t("Топ моделей", "Top models") }
    static var moreInMenuBar: String {
        t("Ещё в меню-баре", "More in the menu bar")
    }

    // Connection
    static var connectTitle: String { t("Подключение аккаунта", "Connect your account") }
    static var connectSafeNote: String {
        t(
            "Токены никуда не отправляются — приложение читает локальные сессии на этом Mac и ходит только на официальные API провайдеров.",
            "No tokens are uploaded — the app reads local sessions on this Mac and only calls each provider’s official API."
        )
    }
    static var providers: String { t("Провайдеры", "Providers") }
    static var primaryProvider: String { t("Основной для виджета", "Primary for widget") }
    static var primaryAutomatic: String { t("Авто (кто больше использовал)", "Auto (highest usage)") }
    static var connectGitHub: String { t("Подключить GitHub (Copilot)", "Connect GitHub (Copilot)") }
    static var waitingGitHub: String { t("Ожидание подтверждения…", "Waiting for confirmation…") }
    static var githubUserCode: String { t("Код", "Code") }
    static var errorDetails: String { t("Подробности", "Details") }
    static var errorLogTitle: String { t("Журнал ошибок", "Error log") }
    static var errorLogSafeNote: String {
        t(
            "Только на этом Mac. Ключи и токены вырезаются. Никуда не отправляется.",
            "Stored only on this Mac. Keys and tokens are redacted. Nothing is uploaded."
        )
    }
    static var clearErrorLog: String { t("Очистить", "Clear") }
    static var copyErrorLog: String { t("Копировать", "Copy") }
    static var noErrorLog: String { t("Записей пока нет.", "No entries yet.") }
    static var step1: String {
        t("1. Установите и откройте Cursor", "1. Install and open Cursor")
    }
    static var step2: String {
        t("2. Войдите в свой аккаунт Cursor", "2. Sign in to your Cursor account")
    }
    static var step3: String {
        t("3. Нажмите «Проверить подключение»", "3. Tap “Check connection”")
    }
    static var openCursor: String { t("Открыть Cursor", "Open Cursor") }
    static var downloadCursor: String { t("Скачать Cursor", "Download Cursor") }
    static var checkConnection: String { t("Проверить подключение", "Check connection") }
    static var cursorInstalled: String { t("Cursor найден", "Cursor found") }
    static var cursorMissing: String { t("Cursor не установлен", "Cursor not installed") }
    static var signedIn: String { t("Аккаунт подключён", "Account connected") }
    static var notSignedIn: String {
        t("Сессия не найдена — войдите в Cursor", "No session found — sign in to Cursor")
    }
    static var noSessionDetail: String {
        t(
            "Войдите в Cursor IDE на этом Mac. Отдельный логин и вставка токенов не нужны.",
            "Sign in to Cursor IDE on this Mac. No separate login or token paste is required."
        )
    }
    static var errorTitle: String { t("Ошибка", "Error") }
    static var noDataTitle: String { t("Нет данных", "No data") }
    static var runAppHint: String {
        t(
            "Запустите Cursor Limits, чтобы обновить данные.",
            "Launch Cursor Limits to refresh data."
        )
    }

    // Settings
    static var status: String { t("Статус", "Status") }
    static var plan: String { t("План", "Plan") }
    static var actions: String { t("Действия", "Actions") }
    static var refreshNow: String { t("Обновить сейчас", "Refresh now") }
    static var openDataFolder: String { t("Открыть папку данных", "Open data folder") }
    static var launchAtLogin: String { t("Запускать при входе в систему", "Launch at login") }
    static var howToConnect: String { t("Как подключить аккаунт", "How to connect") }
    static var language: String { t("Язык", "Language") }
    static var languageSystem: String { t("Как в системе", "Match system") }
    static var cursorSession: String { t("Сессия Cursor", "Cursor session") }
    static var widgetHint: String {
        t(
            "Виджет: ПКМ на рабочем столе → «Редактировать виджеты» → Cursor Limits.",
            "Widget: right-click the desktop → Edit Widgets → Cursor Limits."
        )
    }
    static var privacyNote: String {
        t(
            "Данные usage хранятся только локально на этом Mac.",
            "Usage data stays only on this Mac."
        )
    }
}
