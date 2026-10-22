import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.connectTitle)
                .font(.headline)

            Text(L10n.connectSafeNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.connectStepsHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ProviderID.allCases) { id in
                    providerRow(id)
                }
            }

            if let message = model.lastError
                ?? model.snapshot.primary?.errorMessage,
               !message.isEmpty
            {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                Button(L10n.openSettings) {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }

                Button(L10n.checkConnection) {
                    Task { await model.rediscoverProviders() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRefreshing)
            }

            Text(L10n.widgetHintOptional)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func providerRow(_ id: ProviderID) -> some View {
        let available = ProviderRegistry.provider(for: id)?.isAvailable() ?? false
        return HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(available ? Color.green : Color.secondary)
                .font(.caption)
            Image(systemName: id.symbolName)
                .font(.caption)
                .frame(width: 14)
            Text(id.displayName)
                .font(.caption)
            Spacer(minLength: 0)
            Text(available ? L10n.sessionFound : L10n.sessionMissing)
                .font(.caption2)
                .foregroundStyle(available ? Color.green : Color.secondary)
        }
    }
}
