import Foundation
import UserNotifications

/// Fires local notifications when primary usage crosses 70% / 90% / 100%.
enum UsageAlertNotifier {
    static let thresholds: [Double] = [0.70, 0.90, 1.0]

    struct Crossing: Equatable {
        var threshold: Double
        var fraction: Double
        var providerID: ProviderID
        var providerName: String
    }

    /// Pure logic — which new thresholds were crossed (for tests).
    static func crossings(
        fraction: Double,
        providerID: ProviderID,
        providerName: String,
        lastNotifiedThreshold: Double?,
        cycleKey: String,
        previousCycleKey: String?
    ) -> (crossings: [Crossing], newLast: Double?) {
        if previousCycleKey != cycleKey {
            // New billing window — allow all thresholds again.
            let hit = thresholds.filter { fraction + 0.0001 >= $0 }
            let crossings = hit.map {
                Crossing(threshold: $0, fraction: fraction, providerID: providerID, providerName: providerName)
            }
            return (crossings, hit.last)
        }
        let last = lastNotifiedThreshold ?? -1
        let hit = thresholds.filter { $0 > last && fraction + 0.0001 >= $0 }
        let crossings = hit.map {
            Crossing(threshold: $0, fraction: fraction, providerID: providerID, providerName: providerName)
        }
        let newLast = hit.last ?? lastNotifiedThreshold
        return (crossings, newLast)
    }

    static func isInQuietHours(
        now: Date = Date(),
        calendar: Calendar = .current,
        startHour: Int,
        endHour: Int
    ) -> Bool {
        let hour = calendar.component(.hour, from: now)
        let start = ((startHour % 24) + 24) % 24
        let end = ((endHour % 24) + 24) % 24
        if start == end { return false }
        if start < end {
            return hour >= start && hour < end
        }
        // Wraps midnight, e.g. 22 → 8
        return hour >= start || hour < end
    }

    static func cycleKey(for usage: ProviderUsage) -> String {
        if let reset = usage.windows.compactMap(\.resetsAt).max() {
            return ISO8601DateFormatter().string(from: reset)
        }
        return "none"
    }

    @MainActor
    static func evaluate(snapshot: AppSnapshot, preferences: AppPreferences) async {
        guard preferences.alertsEnabled else { return }
        guard let primary = snapshot.primary, primary.status == .ok,
              let fraction = primary.primaryFraction
        else { return }

        if preferences.quietHoursEnabled,
           isInQuietHours(
            startHour: preferences.quietHoursStartHour,
            endHour: preferences.quietHoursEndHour
           )
        {
            return
        }

        var state = AlertStateStore.load()
        let key = cycleKey(for: primary)
        let previous = state.entries[primary.providerID.rawValue]
        let result = crossings(
            fraction: fraction,
            providerID: primary.providerID,
            providerName: primary.providerID.displayName,
            lastNotifiedThreshold: previous?.lastNotifiedThreshold,
            cycleKey: key,
            previousCycleKey: previous?.cycleKey
        )
        guard !result.crossings.isEmpty else { return }

        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        for crossing in result.crossings {
            postNotification(crossing)
        }

        state.entries[primary.providerID.rawValue] = AlertStateEntry(
            cycleKey: key,
            lastNotifiedThreshold: result.newLast ?? previous?.lastNotifiedThreshold ?? -1
        )
        AlertStateStore.save(state)
    }

    private static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    private static func postNotification(_ crossing: Crossing) {
        let content = UNMutableNotificationContent()
        let pct = Int((crossing.threshold * 100).rounded())
        let used = Int((crossing.fraction * 100).rounded())
        content.title = L10n.t("Лимит \(crossing.providerName)", "\(crossing.providerName) limit")
        content.body = L10n.t(
            "Использовано \(used)% (порог \(pct)%).",
            "Usage at \(used)% (crossed \(pct)%)."
        )
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "usage-\(crossing.providerID.rawValue)-\(pct)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

struct AlertStateEntry: Codable, Equatable, Sendable {
    var cycleKey: String
    var lastNotifiedThreshold: Double
}

struct AlertStateFile: Codable, Equatable, Sendable {
    var entries: [String: AlertStateEntry]

    static var empty: AlertStateFile { AlertStateFile(entries: [:]) }
}

enum AlertStateStore {
    private static let fileName = "alert-state.json"

    private static var fileURL: URL {
        AppPaths.applicationSupportDirectoryURL.appendingPathComponent(fileName)
    }

    static func load() -> AlertStateFile {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(AlertStateFile.self, from: data)
        else { return .empty }
        return file
    }

    static func save(_ file: AlertStateFile) {
        try? SnapshotStore.ensureDirectory()
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
