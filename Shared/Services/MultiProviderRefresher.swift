import Foundation

enum MultiProviderRefresher {
    static func refresh(preferences: AppPreferences = AppPreferencesStore.load()) async -> AppSnapshot {
        let enabled = preferences.enabledProviderIDs.isEmpty
            ? AppPreferencesStore.defaultEnabled
            : preferences.enabledProviderIDs

        var results: [ProviderUsage] = []
        results.reserveCapacity(enabled.count)

        await withTaskGroup(of: ProviderUsage.self) { group in
            for id in enabled {
                guard let provider = ProviderRegistry.provider(for: id) else { continue }
                group.addTask {
                    await provider.refresh()
                }
            }
            for await usage in group {
                results.append(usage)
            }
        }

        // Stable order matching enabled list
        results.sort { a, b in
            let ia = enabled.firstIndex(of: a.providerID) ?? 0
            let ib = enabled.firstIndex(of: b.providerID) ?? 0
            return ia < ib
        }

        return AppSnapshot(
            schemaVersion: AppSnapshot.currentSchemaVersion,
            fetchedAt: Date(),
            providers: results,
            enabledProviderIDs: enabled,
            primaryProviderID: preferences.primaryProviderID
        )
    }
}
