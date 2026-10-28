import AppKit
import SwiftUI

struct NotchLimitsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var state: NotchPanelState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Cards the user folded. Cleared when the panel closes, so the next open
    /// starts with every provider fully expanded.
    @State private var collapsedIDs: Set<String> = []

    private var providers: [ProviderUsage] {
        NotchContent.providers(
            snapshot: model.snapshot,
            enabled: model.preferences.enabledProviderIDs,
            primary: model.preferences.primaryProviderID
        )
    }

    private var blobSize: CGSize {
        NotchLayout.blobSize(
            expanded: state.expanded,
            metrics: state.metrics,
            providerCount: providers.count
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: state.metrics.topClearance)
                .allowsHitTesting(false)
            card
                .frame(width: blobSize.width, height: blobSize.height)
                .opacity(state.expanded ? 1 : 0)
                .allowsHitTesting(state.expanded)
                .accessibilityHidden(!state.expanded)
            Spacer(minLength: 0)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(motion, value: state.expanded)
        .onChange(of: state.expanded) { _, isOpen in
            if !isOpen { collapsedIDs = [] }
        }
    }

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.36, dampingFraction: 0.86)
    }

    private var shape: NotchBlobShape {
        NotchBlobShape(
            notchWidth: state.metrics.isPhysical ? state.metrics.notchWidth : blobSize.width,
            capHeight: state.metrics.capHeight
        )
    }

    private var card: some View {
        ZStack(alignment: .top) {
            shape.fill(Color.black)
            content
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.appName)
    }

    private var content: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: state.metrics.capHeight)
                .allowsHitTesting(false)
            expandedBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if providers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.notchEmpty)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.notchOpenSettings, action: openSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(providers) { usage in
                            ProviderCard(
                                usage: usage,
                                isPrimary: usage.providerID == model.preferences.primaryProviderID,
                                expanded: !collapsedIDs.contains(usage.providerID.rawValue),
                                onToggleExpanded: { toggle(usage.providerID) },
                                fillOpacity: 0.1
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }
                .frame(height: scrollHeight)
            }
        }
        .padding(.top, state.metrics.capHeight > 1 ? 6 : 2)
    }

    private var header: some View {
        HStack(spacing: 8) {
            brand(size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.appName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(footerText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                Task { await model.refresh() }
            } label: {
                if model.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(model.isRefreshing)
            .help(L10n.refresh)

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L10n.actions)
        }
    }

    /// Room left for the provider list once the notch cap, header, and padding are out.
    private var scrollHeight: CGFloat {
        let chrome = state.metrics.capHeight + 62
        return max(140, blobSize.height - chrome)
    }

    private var footerText: String {
        if model.isRefreshing { return L10n.updating }
        if providers.isEmpty { return L10n.notchEmpty }
        return "\(L10n.updated) \(Formatters.timeAgo(model.snapshot.fetchedAt))"
    }

    private func brand(size: CGFloat) -> some View {
        Image("BrandIcon")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size > 18 ? 5 : 4, style: .continuous))
    }

    private func toggle(_ id: ProviderID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            let key = id.rawValue
            if collapsedIDs.contains(key) {
                collapsedIDs.remove(key)
            } else {
                collapsedIDs.insert(key)
            }
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
