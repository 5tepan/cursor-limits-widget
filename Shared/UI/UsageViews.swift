import SwiftUI

struct ProgressRing: View {
    var progress: Double?
    var lineWidth: CGFloat = 8
    var size: CGFloat = 64

    private var clamped: Double {
        min(max(progress ?? 0, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    Formatters.usageColor(progress),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(Formatters.percent(progress))
                .font(.system(size: size * 0.22, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

struct UsageBar: View {
    var title: String
    var fraction: Double?
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(detail ?? Formatters.percent(fraction))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.10))
                    Capsule()
                        .fill(Formatters.usageColor(fraction))
                        .frame(width: max(4, geo.size.width * min(max(fraction ?? 0, 0), 1)))
                }
            }
            .frame(height: 6)
        }
    }
}

struct MetricChip: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusPlaceholder: View {
    var usage: ProviderUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var title: String {
        switch usage?.status {
        case .authMissing: return L10n.notSignedIn
        case .error: return L10n.errorTitle
        case .missing, .none: return L10n.noDataTitle
        case .ok: return "OK"
        }
    }

    private var message: String {
        if let usage {
            return ProviderErrorCopy.shortStatus(for: usage, enabled: true)
        }
        return L10n.runAppHint
    }
}
