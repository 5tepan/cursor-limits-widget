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
    static var connectTitle: String { t("Подключите провайдеров", "Connect your providers") }
    static var connectSafeNote: String {
        t(
            "Токены никуда не отправляются — приложение читает локальные сессии на этом Mac и ходит только на официальные API провайдеров.",
            "No tokens are uploaded — the app reads local sessions on this Mac and only calls each provider’s official API."
        )
    }
    static var connectStepsHint: String {
        t(
            "Войдите в нужные инструменты на этом Mac, затем нажмите «Проверить». Copilot — через Настройки.",
            "Sign in to the tools you use on this Mac, then tap Check. Copilot is connected in Settings."
        )
    }
    static var providers: String { t("Провайдеры", "Providers") }
    static var primaryProvider: String { t("Основной (меню-бар и виджет)", "Primary (menu bar & widget)") }
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
    static var openSettings: String { t("Настройки", "Settings") }
    static var openCursor: String { t("Открыть Cursor", "Open Cursor") }
    static var downloadCursor: String { t("Скачать Cursor", "Download Cursor") }
    static var checkConnection: String { t("Проверить", "Check") }
    static var rediscoverProviders: String {
        t("Пересканировать провайдеров", "Rescan providers")
    }
    static var rediscoverProvidersHint: String {
        t(
            "Включит все источники, отключит без локальной сессии. Ручной выбор сохранится после этого.",
            "Enables all sources, turns off those without a local session. Your manual choice is kept afterward."
        )
    }
    static var sessionFound: String { t("сессия есть", "session found") }
    static var sessionMissing: String { t("нет сессии", "no session") }
    static var cursorInstalled: String { t("Cursor найден", "Cursor found") }
    static var cursorMissing: String { t("Cursor не установлен", "Cursor not installed") }
    static var signedIn: String { t("Аккаунт подключён", "Account connected") }
    static var notSignedIn: String {
        t("Сессия не найдена", "No session found")
    }
    static var noSessionDetail: String {
        t(
            "Войдите в Cursor IDE (или другой провайдер) на этом Mac. Отдельный логин и вставка токенов не нужны.",
            "Sign in to Cursor IDE (or another provider) on this Mac. No separate login or token paste is required."
        )
    }
    static var widgetHintOptional: String {
        t(
            "Виджеты на рабочем столе пока могут не работать — надёжная поверхность сейчас меню-бар.",
            "Desktop widgets may not work yet — the menu bar is the supported surface today."
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
    static var alertsSection: String { t("Уведомления", "Alerts") }
    static var alertsEnabled: String {
        t("Уведомлять при 70% / 90% / 100%", "Notify at 70% / 90% / 100%")
    }
    static var alertsHint: String {
        t(
            "Только для основного провайдера. Повторно — после смены цикла.",
            "Primary provider only. Fires again after the billing cycle resets."
        )
    }
    static var quietHours: String { t("Тихие часы", "Quiet hours") }
    static var quietHoursHint: String {
        t("Не беспокоить в этом интервале (может через полночь).", "Mute alerts in this window (may wrap midnight).")
    }
    static var compactMenuBarTitle: String {
        t("Компактный title: % · дни до сброса", "Compact title: % · days until reset")
    }
    static var howToConnect: String { t("Как подключить аккаунт", "How to connect") }
    static var language: String { t("Язык", "Language") }
    static var languageSystem: String { t("Как в системе", "Match system") }
    static var cursorSession: String { t("Сессия Cursor", "Cursor session") }
    static var widgetHint: String {
        t(
            "Виджет (нестабильно): ПКМ на рабочем столе → «Редактировать виджеты» → Cursor Limits.",
            "Widget (unreliable): right-click the desktop → Edit Widgets → Cursor Limits."
        )
    }
    static var privacyNote: String {
        t(
            "Данные usage хранятся только локально на этом Mac.",
            "Usage data stays only on this Mac."
        )
    }
}
