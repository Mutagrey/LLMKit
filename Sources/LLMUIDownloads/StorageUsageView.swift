import Foundation
import SwiftUI

public struct StorageUsageView: View {
    private let downloadedModelCount: Int
    private let totalModelCount: Int
    private let installedBytes: Int64
    private let partialBytes: Int64
    private let availableBytes: Int64?
    private let capacityBytes: Int64?

    public init(
        downloadedModelCount: Int,
        totalModelCount: Int,
        installedBytes: Int64,
        partialBytes: Int64,
        availableBytes: Int64? = nil,
        capacityBytes: Int64? = nil
    ) {
        self.downloadedModelCount = downloadedModelCount
        self.totalModelCount = totalModelCount
        self.installedBytes = installedBytes
        self.partialBytes = partialBytes
        self.availableBytes = availableBytes
        self.capacityBytes = capacityBytes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                metric(value: "\(downloadedModelCount)/\(totalModelCount)", label: "Models", tint: .green)
                metric(value: byteCountTitle(installedBytes), label: "Installed", tint: .blue)
                metric(value: byteCountTitle(partialBytes), label: "Partial", tint: .orange)
            }

            if let diskTitle {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(diskTitle)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(diskPercentTitle)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(diskTint)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                            Capsule(style: .continuous)
                                .fill(diskTint.opacity(0.8))
                                .frame(width: max(geometry.size.width * diskUsedFraction, 4))
                        }
                    }
                    .frame(height: 5)
                    .clipShape(Capsule(style: .continuous))
                    .accessibilityLabel("Disk usage")
                    .accessibilityValue(diskPercentTitle)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        }
    }

    private func metric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var diskTitle: String? {
        guard let availableBytes, let capacityBytes, capacityBytes > 0 else {
            return nil
        }
        return "\(byteCountTitle(availableBytes)) free of \(byteCountTitle(capacityBytes))"
    }

    private var diskUsedFraction: Double {
        guard let availableBytes, let capacityBytes, capacityBytes > 0 else {
            return 0
        }
        return min(max(Double(capacityBytes - availableBytes) / Double(capacityBytes), 0), 1)
    }

    private var diskPercentTitle: String {
        "\(Int((diskUsedFraction * 100).rounded()))%"
    }

    private var diskTint: Color {
        switch diskUsedFraction {
        case 0.85...:
            return .red
        case 0.7..<0.85:
            return .orange
        default:
            return .green
        }
    }

    private func byteCountTitle(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
