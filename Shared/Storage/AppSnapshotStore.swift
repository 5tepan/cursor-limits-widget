import Foundation

enum AppSnapshotStore {
    static let fileName = "app-snapshot.json"

    private static var candidateURLs: [URL] {
        var seen = Set<String>()
        var urls: [URL] = []
        for dir in [
            SnapshotStore.applicationSupportDirectoryURL,
            SnapshotStore.widgetContainerDirectoryURL,
            SnapshotStore.processApplicationSupportDirectoryURL
        ] {
            let url = dir.appendingPathComponent(fileName)
            if seen.insert(url.path).inserted {
                urls.append(url)
            }
        }
        return urls
    }

    static func load() -> AppSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for url in candidateURLs {
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let snap = try? decoder.decode(AppSnapshot.self, from: data)
            else { continue }
            return snap
        }
        // Migrate legacy single Cursor snapshot if present
        if let legacy = SnapshotStore.load() {
            let cursor = CursorUsageProvider().mapLegacy(legacy)
            return AppSnapshot(
                schemaVersion: AppSnapshot.currentSchemaVersion,
                fetchedAt: legacy.fetchedAt,
                providers: [cursor],
                enabledProviderIDs: AppPreferencesStore.defaultEnabled,
                primaryProviderID: .cursor
            )
        }
        return nil
    }

    static func save(_ snapshot: AppSnapshot) throws {
        try SnapshotStore.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        var wrote = false
        var lastError: Error?
        for url in candidateURLs {
            do {
                try data.write(to: url, options: .atomic)
                wrote = true
            } catch {
                lastError = error
            }
        }
        // Also keep legacy Cursor snapshot for older widget builds
        if let cursor = snapshot.providers.first(where: { $0.providerID == .cursor }) {
            try? SnapshotStore.save(cursor.asLegacySnapshot())
        }
        if !wrote, let lastError { throw lastError }
    }
}

private extension CursorUsageProvider {
    func mapLegacy(_ snap: UsageSnapshot) -> ProviderUsage {
        // Reuse refresh mapper by constructing through temporary refresh path is heavy;
        // inline the same mapping used in CursorUsageProvider.map
        var windows: [UsageWindow] = []
        if let auto = snap.autoPercentUsed {
            windows.append(UsageWindow(label: "Auto", fraction: auto, resetsAt: snap.billingCycleEnd))
        }
        if let api = snap.apiPercentUsed {
            windows.append(UsageWindow(label: "API", fraction: api, resetsAt: snap.billingCycleEnd))
        }
        return ProviderUsage(
            providerID: .cursor,
            status: snap.status,
            planName: snap.planName,
            email: snap.email,
            windows: windows,
            displayMessage: snap.displayMessage,
            errorMessage: snap.errorMessage,
            fetchedAt: snap.fetchedAt,
            tokenStats: snap.tokenStats,
            topModels: snap.topModels,
            includedSpend: snap.includedSpend,
            totalSpend: snap.totalSpend,
            onDemandEnabled: snap.onDemandEnabled,
            onDemandUsedCents: snap.onDemandUsedCents
        )
    }
}

private extension ProviderUsage {
    func asLegacySnapshot() -> UsageSnapshot {
        let auto = windows.first(where: { $0.label == "Auto" })?.fraction
        let api = windows.first(where: { $0.label == "API" })?.fraction
        let total = primaryFraction
        return UsageSnapshot(
            fetchedAt: fetchedAt,
            email: email,
            planName: planName,
            membershipType: nil,
            billingCycleStart: nil,
            billingCycleEnd: windows.compactMap(\.resetsAt).max(),
            autoPercentUsed: auto,
            apiPercentUsed: api,
            totalPercentUsed: total,
            planUsed: nil,
            planLimit: nil,
            planRemaining: nil,
            includedSpend: includedSpend,
            totalSpend: totalSpend,
            bonusSpend: nil,
            onDemandEnabled: onDemandEnabled,
            onDemandUsedCents: onDemandUsedCents,
            onDemandLimitCents: nil,
            displayMessage: displayMessage,
            tokenStats: tokenStats,
            topModels: topModels,
            status: status,
            errorMessage: errorMessage
        )
    }
}
