import Foundation
import SwiftUI
import LLMUIStorage

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

    public init(summary: ModelStorageSummary) {
        self.init(
            downloadedModelCount: summary.downloadedModelCount,
            totalModelCount: summary.totalModelCount,
            installedBytes: summary.installedBytes,
            partialBytes: summary.partialBytes,
            availableBytes: summary.availableBytes,
            capacityBytes: summary.capacityBytes
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                metric(
                    value: "\(max(downloadedModelCount, 0))/\(max(totalModelCount, 0))",
                    label: "Models",
                    tint: .green,
                    transitionValue: Double(max(downloadedModelCount, 0))
                )
                metric(
                    value: byteCountTitle(positiveInstalledBytes),
                    label: "Installed",
                    tint: .blue,
                    transitionValue: Double(positiveInstalledBytes)
                )
                metric(
                    value: byteCountTitle(positivePartialBytes),
                    label: "Partial",
                    tint: .orange,
                    transitionValue: Double(positivePartialBytes)
                )
            }

            storageBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(value: String, label: String, tint: Color, transitionValue: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText(value: transitionValue))
                .animation(.easeInOut(duration: 0.2), value: transitionValue)

            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var storageBar: some View {
        if let diskUsage {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(storageStatusTitle) · \(diskUsedTitle)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.numericText(value: Double(diskUsage.usedBytes)))
                        .animation(.easeInOut(duration: 0.2), value: diskUsage.usedBytes)
                    Spacer(minLength: 8)
                    Text(diskFreeTitle)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(diskTint)
                        .lineLimit(1)
                        .contentTransition(.numericText(value: Double(diskUsage.availableBytes)))
                        .animation(.easeInOut(duration: 0.2), value: diskUsage.availableBytes)
                }

                StorageUsageBarView(
                    segments: diskChartSegments,
                    totalBytes: diskUsage.capacityBytes,
                    accessibilityLabel: "Disk usage",
                    accessibilityValue: "\(diskFreeTitle), \(diskUsedTitle)"
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Model storage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(modelStorageTitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(modelStorageBytes)))
                        .animation(.easeInOut(duration: 0.2), value: modelStorageBytes)
                }

                StorageUsageBarView(
                    segments: modelChartSegments,
                    totalBytes: max(modelStorageBytes, 1),
                    accessibilityLabel: "Model storage",
                    accessibilityValue: modelStorageTitle
                )
            }
        }
    }

    private var diskFreeTitle: String {
        guard let diskUsage else {
            return modelStorageTitle
        }
        return "\(byteCountTitle(diskUsage.availableBytes)) free"
    }

    private var diskFreeFraction: Double {
        guard let diskUsage else {
            return 0
        }
        return min(max(Double(diskUsage.availableBytes) / Double(diskUsage.capacityBytes), 0), 1)
    }

    private var diskUsedTitle: String {
        guard let diskUsage else {
            return modelStorageTitle
        }
        return "\(byteCountTitle(diskUsage.usedBytes)) of \(byteCountTitle(diskUsage.capacityBytes)) used"
    }

    private var storageStatusTitle: String {
        switch diskFreeFraction {
        case ...0.15:
            return "Low space"
        case ..<0.3:
            return "High usage"
        default:
            return "Healthy"
        }
    }

    private var diskTint: Color {
        switch diskFreeFraction {
        case ...0.15:
            return .red
        case ..<0.3:
            return .orange
        default:
            return .green
        }
    }

    private var diskUsage: DiskStorageUsage? {
        guard
            let availableBytes,
            let capacityBytes,
            capacityBytes > 0,
            availableBytes >= 0,
            availableBytes <= capacityBytes
        else {
            return nil
        }
        return DiskStorageUsage(
            availableBytes: availableBytes,
            capacityBytes: capacityBytes,
            usedBytes: capacityBytes - availableBytes
        )
    }

    private var diskChartSegments: [StorageUsageBarSegment] {
        guard let diskUsage else {
            return []
        }
        let modelBytes = scaledModelBytes(toFit: diskUsage.usedBytes)
        let otherUsedBytes = max(diskUsage.usedBytes - modelBytes.installed - modelBytes.partial, 0)
        return chartSegments([
            ("Other used", otherUsedBytes, .gray.opacity(0.68)),
            ("Installed", modelBytes.installed, .blue.opacity(0.9)),
            ("Partial", modelBytes.partial, .orange.opacity(0.9)),
            ("Free", diskUsage.availableBytes, .secondary.opacity(0.18))
        ])
    }

    private var modelChartSegments: [StorageUsageBarSegment] {
        chartSegments([
            ("Installed", positiveInstalledBytes, .blue.opacity(0.9)),
            ("Partial", positivePartialBytes, .orange.opacity(0.9))
        ])
    }

    private var positiveInstalledBytes: Int64 {
        max(installedBytes, 0)
    }

    private var positivePartialBytes: Int64 {
        max(partialBytes, 0)
    }

    private var modelStorageBytes: Int64 {
        positiveInstalledBytes + positivePartialBytes
    }

    private var modelStorageTitle: String {
        guard modelStorageBytes > 0 else {
            return "No artifacts"
        }
        return byteCountTitle(modelStorageBytes)
    }

    private func scaledModelBytes(toFit usedBytes: Int64) -> (installed: Int64, partial: Int64) {
        let modelBytes = modelStorageBytes
        guard modelBytes > usedBytes, modelBytes > 0 else {
            return (positiveInstalledBytes, positivePartialBytes)
        }
        let installedFraction = Double(positiveInstalledBytes) / Double(modelBytes)
        let installed = min(usedBytes, Int64((Double(usedBytes) * installedFraction).rounded()))
        return (installed, max(usedBytes - installed, 0))
    }

    private func chartSegments(_ parts: [(title: String, bytes: Int64, tint: Color)]) -> [StorageUsageBarSegment] {
        return parts.compactMap { part in
            let bytes = max(part.bytes, 0)
            guard bytes > 0 else {
                return nil
            }
            return StorageUsageBarSegment(
                title: part.title,
                bytes: bytes,
                tint: part.tint
            )
        }
    }

    private func byteCountTitle(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct DiskStorageUsage {
    let availableBytes: Int64
    let capacityBytes: Int64
    let usedBytes: Int64
}
