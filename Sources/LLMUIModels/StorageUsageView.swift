import Charts
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
                    Text(diskPercentTitle)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(diskTint)
                        .contentTransition(.numericText(value: diskFreeFraction))
                        .animation(.easeInOut(duration: 0.2), value: diskFreeFraction)
                }

                storageChart(
                    segments: diskChartSegments,
                    totalBytes: diskUsage.capacityBytes,
                    accessibilityLabel: "Disk usage",
                    accessibilityValue: "\(diskPercentTitle), \(diskUsedTitle)"
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

                storageChart(
                    segments: modelChartSegments,
                    totalBytes: max(modelStorageBytes, 1),
                    accessibilityLabel: "Model storage",
                    accessibilityValue: modelStorageTitle
                )
            }
        }
    }

    private func storageChart(
        segments: [StorageChartSegment],
        totalBytes: Int64,
        accessibilityLabel: String,
        accessibilityValue: String
    ) -> some View {
        Chart(segments) { segment in
            BarMark(
                x: .value("Storage Size", Double(segment.bytes))
            )
            .foregroundStyle(by: .value("Storage Category", segment.title))
            .accessibilityLabel(segment.title)
            .accessibilityValue(byteCountTitle(segment.bytes))
        }
        .chartXScale(domain: 0...max(Double(totalBytes), 1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(range: .plotDimension(endPadding: -8))
        .chartLegend(.hidden)
        .chartForegroundStyleScale([
            "Installed": Color.blue.opacity(0.9),
            "Partial": Color.orange.opacity(0.9),
            "Other used": Color.gray.opacity(0.68),
            "Free": Color.secondary.opacity(0.18)
        ])
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(height: 25)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .animation(.easeInOut(duration: 0.25), value: chartAnimationValue(for: segments))
    }

    private var diskPercentTitle: String {
        "\(Int((diskFreeFraction * 100).rounded()))% free"
    }

    private var diskUsedFraction: Double {
        guard let diskUsage else {
            return 0
        }
        return min(max(Double(diskUsage.usedBytes) / Double(diskUsage.capacityBytes), 0), 1)
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

    private var diskChartSegments: [StorageChartSegment] {
        guard let diskUsage else {
            return []
        }
        let modelBytes = scaledModelBytes(toFit: diskUsage.usedBytes)
        let otherUsedBytes = max(diskUsage.usedBytes - modelBytes.installed - modelBytes.partial, 0)
        return chartSegments([
            ("Other used", otherUsedBytes),
            ("Installed", modelBytes.installed),
            ("Partial", modelBytes.partial),
            ("Free", diskUsage.availableBytes)
        ])
    }

    private var modelChartSegments: [StorageChartSegment] {
        chartSegments([
            ("Installed", positiveInstalledBytes),
            ("Partial", positivePartialBytes)
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

    private func chartSegments(_ parts: [(title: String, bytes: Int64)]) -> [StorageChartSegment] {
        return parts.compactMap { part in
            let bytes = max(part.bytes, 0)
            guard bytes > 0 else {
                return nil
            }
            return StorageChartSegment(
                title: part.title,
                bytes: bytes
            )
        }
    }

    private func chartAnimationValue(for segments: [StorageChartSegment]) -> Double {
        segments.reduce(0) { partialResult, segment in
            partialResult + Double(segment.bytes)
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

private struct StorageChartSegment: Identifiable {
    let title: String
    let bytes: Int64

    var id: String {
        title
    }
}
