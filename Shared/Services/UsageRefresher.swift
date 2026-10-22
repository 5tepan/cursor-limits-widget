import Foundation

enum UsageRefresher {
    static func refresh() async -> UsageSnapshot {
        guard var credentials = CursorCredentialsLoader.load() else {
            var snap = UsageSnapshot.empty
            snap.status = .authMissing
            snap.errorMessage = L10n.noSessionDetail
            snap.fetchedAt = Date()
            return snap
        }

        do {
            if CursorCredentialsLoader.isExpired(credentials.accessToken),
               credentials.refreshToken != nil
            {
                credentials = try await CursorTokenRefresher.refresh(credentials)
            }

            let period = try await CursorAPI.fetchCurrentPeriodUsage(token: credentials.accessToken)
            let planInfo = try? await CursorAPI.fetchPlanInfo(token: credentials.accessToken)

            var snapshot = mapPeriod(period, planInfo: planInfo?.planInfo, credentials: credentials)

            if let cookie = CursorCredentialsLoader.workosSessionCookie(from: credentials) {
                if let summary = try? await CursorAPI.fetchUsageSummary(cookieHeader: cookie) {
                    applySummary(summary, to: &snapshot)
                }

                if let events = try? await CursorAPI.fetchUsageEvents(
                    cookieHeader: cookie,
                    start: snapshot.billingCycleStart,
                    end: snapshot.billingCycleEnd ?? Date()
                ) {
                    applyEvents(events, to: &snapshot)
                }
            }

            snapshot.status = .ok
            snapshot.fetchedAt = Date()
            return snapshot
        } catch let apiError as CursorAPI.APIError {
            let userMessage = ProviderErrorCopy.humanize(apiError.errorDescription)
                ?? L10n.t("Ошибка обновления", "Refresh failed")
            ProviderDiagnosticsStore.record(
                provider: .cursor,
                summary: userMessage,
                detail: apiError.diagnosticDetail
            )
            var snap = SnapshotStore.load() ?? UsageSnapshot.empty
            snap.status = .error
            snap.errorMessage = userMessage
            snap.fetchedAt = Date()
            return snap
        } catch {
            let raw = error.localizedDescription
            let userMessage = ProviderErrorCopy.humanize(raw)
                ?? L10n.t("Ошибка обновления", "Refresh failed")
            ProviderDiagnosticsStore.record(
                provider: .cursor,
                summary: userMessage,
                detail: SecretRedactor.redact(raw)
            )
            var snap = SnapshotStore.load() ?? UsageSnapshot.empty
            snap.status = .error
            snap.errorMessage = userMessage
            snap.fetchedAt = Date()
            return snap
        }
    }

    // MARK: - Mapping

    private static func mapPeriod(
        _ period: CursorAPI.PeriodUsageResponse,
        planInfo: CursorAPI.PlanInfoResponse.PlanInfo?,
        credentials: CursorCredentials
    ) -> UsageSnapshot {
        let usage = period.planUsage
        return UsageSnapshot(
            fetchedAt: Date(),
            email: credentials.email,
            planName: planInfo?.planName
                ?? credentials.membershipType?.capitalized
                ?? "Cursor",
            membershipType: credentials.membershipType,
            billingCycleStart: parseDate(period.billingCycleStart),
            billingCycleEnd: parseDate(period.billingCycleEnd) ?? parseDate(planInfo?.billingCycleEnd),
            autoPercentUsed: usage?.autoPercentUsed.map { $0 / 100.0 },
            apiPercentUsed: usage?.apiPercentUsed.map { $0 / 100.0 },
            totalPercentUsed: usage?.totalPercentUsed.map { $0 / 100.0 },
            planUsed: usage.map { ($0.limit ?? 0) - ($0.remaining ?? 0) },
            planLimit: usage?.limit,
            planRemaining: usage?.remaining,
            includedSpend: usage?.includedSpend,
            totalSpend: usage?.totalSpend,
            bonusSpend: usage?.bonusSpend,
            onDemandEnabled: false,
            onDemandUsedCents: nil,
            onDemandLimitCents: nil,
            displayMessage: period.displayMessage,
            tokenStats: nil,
            topModels: [],
            status: .ok,
            errorMessage: nil
        )
    }

    private static func applySummary(_ summary: CursorAPI.UsageSummaryResponse, to snapshot: inout UsageSnapshot) {
        if let start = parseDate(summary.billingCycleStart) {
            snapshot.billingCycleStart = start
        }
        if let end = parseDate(summary.billingCycleEnd) {
            snapshot.billingCycleEnd = end
        }
        if let membership = summary.membershipType, snapshot.membershipType == nil {
            snapshot.membershipType = membership
            if snapshot.planName == "Cursor" || snapshot.planName == "—" {
                snapshot.planName = membership.capitalized
            }
        }

        if let plan = summary.individualUsage?.plan {
            if let auto = plan.autoPercentUsed { snapshot.autoPercentUsed = auto / 100.0 }
            if let api = plan.apiPercentUsed { snapshot.apiPercentUsed = api / 100.0 }
            if let total = plan.totalPercentUsed { snapshot.totalPercentUsed = total / 100.0 }
            snapshot.planUsed = plan.used
            snapshot.planLimit = plan.limit
            snapshot.planRemaining = plan.remaining
        }

        if let onDemand = summary.individualUsage?.onDemand {
            snapshot.onDemandEnabled = onDemand.enabled ?? false
            snapshot.onDemandUsedCents = onDemand.used
            snapshot.onDemandLimitCents = onDemand.limit
        }

        if snapshot.displayMessage == nil {
            snapshot.displayMessage = summary.autoModelSelectedDisplayMessage
                ?? summary.namedModelSelectedDisplayMessage
        }
    }

    private static func applyEvents(_ events: CursorAPI.FilteredEventsResponse, to snapshot: inout UsageSnapshot) {
        let list = events.usageEventsDisplay ?? []
        var input = 0, output = 0, cacheRead = 0, cacheWrite = 0
        var charged: Double = 0
        var models: [String: (requests: Int, tokens: Int, cents: Double)] = [:]

        for event in list {
            let tu = event.tokenUsage
            let i = tu?.inputTokens ?? 0
            let o = tu?.outputTokens ?? 0
            let cr = tu?.cacheReadTokens ?? 0
            let cw = tu?.cacheWriteTokens ?? 0
            input += i
            output += o
            cacheRead += cr
            cacheWrite += cw
            let cents = event.chargedCents ?? tu?.totalCents ?? 0
            charged += cents

            let name = event.model ?? "unknown"
            var entry = models[name] ?? (0, 0, 0)
            entry.requests += 1
            entry.tokens += i + o + cr + cw
            entry.cents += cents
            models[name] = entry
        }

        snapshot.tokenStats = TokenStats(
            inputTokens: input,
            outputTokens: output,
            cacheReadTokens: cacheRead,
            cacheWriteTokens: cacheWrite,
            eventCount: list.count,
            chargedCents: charged
        )

        snapshot.topModels = models
            .map { ModelUsage(name: $0.key, requests: $0.value.requests, tokens: $0.value.tokens, chargedCents: $0.value.cents) }
            .sorted { $0.requests > $1.requests }
            .prefix(5)
            .map { $0 }
    }

    static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let ms = Double(raw) {
            let seconds = ms > 10_000_000_000 ? ms / 1000.0 : ms
            return Date(timeIntervalSince1970: seconds)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }
}
