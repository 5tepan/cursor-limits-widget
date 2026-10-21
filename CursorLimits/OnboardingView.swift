import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.connectTitle)
                .font(.headline)

            Text(L10n.connectSafeNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Label(L10n.step1, systemImage: "1.circle.fill")
                Label(L10n.step2, systemImage: "2.circle.fill")
                Label(L10n.step3, systemImage: "3.circle.fill")
            }
            .font(.caption)

            HStack(spacing: 8) {
                statusPill(
                    ok: AccountConnection.isCursorInstalled,
                    okText: L10n.cursorInstalled,
                    badText: L10n.cursorMissing
                )
                statusPill(
                    ok: AccountConnection.hasLocalSession,
                    okText: L10n.signedIn,
                    badText: L10n.notSignedIn
                )
            }

            if let message = model.snapshot.errorMessage ?? model.lastError,
               model.snapshot.status == .error
            {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                if AccountConnection.isCursorInstalled {
                    Button(L10n.openCursor) {
                        AccountConnection.openCursor()
                    }
                } else {
                    Button(L10n.downloadCursor) {
                        AccountConnection.openCursorDownload()
                    }
                }

                Button(L10n.checkConnection) {
                    Task { await model.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRefreshing)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusPill(ok: Bool, okText: String, badText: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            Text(ok ? okText : badText)
                .lineLimit(1)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((ok ? Color.green : Color.orange).opacity(0.15))
        .foregroundStyle(ok ? Color.green : Color.orange)
        .clipShape(Capsule())
    }
}
