import Foundation

struct CursorUsageProvider: UsageProvider {
    let id: ProviderID = .cursor

    func isAvailable() -> Bool {
        // Sealed rows still count — refresh will ask for Keychain access.
        CursorCredentialsLoader.hasStoredToken()
    }

    func refresh() async -> ProviderUsage {
        let snap = await UsageRefresher.refresh()
        return map(snap)
    }

    private func map(_ snap: UsageSnapshot) -> ProviderUsage {
        var windows: [UsageWindow] = []
        if let auto = snap.autoPercentUsed {
            windows.append(UsageWindow(label: "Auto", fraction: auto, resetsAt: snap.billingCycleEnd))
        }
        if let api = snap.apiPercentUsed {
            windows.append(UsageWindow(label: "API", fraction: api, resetsAt: snap.billingCycleEnd))
        }
        if windows.isEmpty, let total = snap.totalPercentUsed {
            windows.append(UsageWindow(label: "Total", fraction: total, resetsAt: snap.billingCycleEnd))
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
