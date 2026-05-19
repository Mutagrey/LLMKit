import SwiftUI

public struct FreeMemoryIndicatorView: View {
    private let availableBytes: UInt64?
    private let totalBytes: UInt64?
    private let title: String

    public init(
        availableBytes: UInt64?,
        totalBytes: UInt64? = nil,
        title: String = "RAM"
    ) {
        self.availableBytes = availableBytes
        self.totalBytes = totalBytes
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "memorychip.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text(label)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .accessibilityLabel(accessibilityLabel)
    }

    private var label: String {
        guard let availableBytes else {
            return "\(title) unavailable"
        }
        if let totalBytes, totalBytes > 0 {
            let percent = Double(min(availableBytes, totalBytes)) / Double(totalBytes) * 100
            return "\(title) \(formatted(availableBytes)) free (\(Int(percent.rounded()))%)"
        }
        return "\(title) \(formatted(availableBytes)) free"
    }

    private var accessibilityLabel: String {
        guard let availableBytes else {
            return "\(title) memory unavailable"
        }
        return "\(title) \(formatted(availableBytes)) free"
    }

    private func formatted(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(min(bytes, UInt64(Int64.max))),
            countStyle: .memory
        )
    }
}

#Preview {
    FreeMemoryIndicatorView(
        availableBytes: 1_500_000_000,
        totalBytes: 8_000_000_000
    )
    .padding()
}
