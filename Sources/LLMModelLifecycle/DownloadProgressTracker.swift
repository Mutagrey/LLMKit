import Foundation
import LLMCore

final class DownloadProgressTracker: @unchecked Sendable {
    let totalExpectedBytes: Int64?
    let isTotalEstimated: Bool
    let totalArtifacts: Int
    private(set) var completedBytes: Int64
    private(set) var completedArtifacts: Int
    var lastReportedProgress: Double

    private var artifactExpectedBytes: [String: Int64]
    private var artifactBaselines: [String: Int64]
    private var artifactCountingModes: [String: ArtifactCountingMode]
    private var currentArtifactBytes: [String: Int64]

    init(totalExpectedBytes: Int64?, isTotalEstimated: Bool, totalArtifacts: Int) {
        self.totalExpectedBytes = totalExpectedBytes
        self.isTotalEstimated = isTotalEstimated
        self.totalArtifacts = totalArtifacts
        self.completedBytes = 0
        self.completedArtifacts = 0
        self.lastReportedProgress = 0
        self.artifactExpectedBytes = [:]
        self.artifactBaselines = [:]
        self.artifactCountingModes = [:]
        self.currentArtifactBytes = [:]
    }

    static func normalizedFraction(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }
        let fraction = value >= 2 && value <= 100 ? value / 100 : value
        return min(max(fraction, 0), 1)
    }

    func restoreCompletedArtifact(_ artifact: ModelArtifact, bytes: Int64) -> ModelInstallProgress {
        recordExpectedBytes(for: artifact)
        completedArtifacts += 1
        completedBytes += artifact.byteCount ?? bytes
        return detail(currentArtifactBytes: 0)
    }

    func restorePartialArtifact(_ artifact: ModelArtifact, bytes: Int64) -> ModelInstallProgress? {
        recordExpectedBytes(for: artifact)
        let baseline = cappedArtifactBytes(artifactID: artifact.id, bytes: bytes)
        guard baseline > 0 else {
            return nil
        }

        artifactBaselines[artifact.id] = max(artifactBaselines[artifact.id] ?? 0, baseline)
        currentArtifactBytes[artifact.id] = max(currentArtifactBytes[artifact.id] ?? 0, baseline)
        return detail(currentArtifactBytes: baseline)
    }

    func updateArtifactProgress(_ progress: ModelArtifactDownloadProgress) -> ModelInstallProgress {
        if let expectedTotalBytes = progress.expectedTotalBytes, expectedTotalBytes > 0 {
            artifactExpectedBytes[progress.artifactID] = expectedTotalBytes
        }

        let currentBytes = effectiveBytes(
            artifactID: progress.artifactID,
            reportedBytes: max(progress.bytesWritten, 0)
        )
        currentArtifactBytes[progress.artifactID] = currentBytes
        return detail(currentArtifactBytes: currentBytes)
    }

    func completeArtifact(_ artifact: ModelArtifact, resultBytes: Int64) -> ModelInstallProgress {
        recordExpectedBytes(for: artifact)
        let currentBytes = currentArtifactBytes[artifact.id] ?? 0
        let fallbackBytes = max(resultBytes, currentBytes)
        let completedArtifactBytes = artifactExpectedBytes[artifact.id]
            ?? artifact.byteCount
            ?? fallbackBytes

        completedArtifacts += 1
        completedBytes += max(completedArtifactBytes, currentBytes)
        artifactBaselines[artifact.id] = nil
        artifactCountingModes[artifact.id] = nil
        currentArtifactBytes[artifact.id] = nil
        return detail(currentArtifactBytes: 0)
    }

    private func recordExpectedBytes(for artifact: ModelArtifact) {
        if artifactExpectedBytes[artifact.id] == nil,
           let byteCount = artifact.byteCount,
           byteCount > 0 {
            artifactExpectedBytes[artifact.id] = byteCount
        }
    }

    private func effectiveBytes(artifactID: String, reportedBytes: Int64) -> Int64 {
        let baseline = artifactBaselines[artifactID] ?? 0
        if baseline > 0, reportedBytes == 0, artifactCountingModes[artifactID] == nil {
            return max(baseline, currentArtifactBytes[artifactID] ?? 0)
        }

        let mode = artifactCountingModes[artifactID] ?? {
            let resolvedMode: ArtifactCountingMode = baseline > 0 && reportedBytes < baseline
                ? .relativeToBaseline
                : .absolute
            artifactCountingModes[artifactID] = resolvedMode
            return resolvedMode
        }()

        let rawEffectiveBytes: Int64
        switch mode {
        case .absolute:
            rawEffectiveBytes = max(reportedBytes, baseline)
        case .relativeToBaseline:
            rawEffectiveBytes = baseline + reportedBytes
        }

        let capped = cappedArtifactBytes(artifactID: artifactID, bytes: rawEffectiveBytes)
        return max(capped, currentArtifactBytes[artifactID] ?? 0)
    }

    private func cappedArtifactBytes(artifactID: String, bytes: Int64) -> Int64 {
        guard let expectedBytes = artifactExpectedBytes[artifactID], expectedBytes > 0 else {
            return max(bytes, 0)
        }
        return min(max(bytes, 0), expectedBytes)
    }

    private func detail(currentArtifactBytes: Int64) -> ModelInstallProgress {
        let totalExpectedBytes = progressTotalBytes()
        let progress = progressValue(
            currentArtifactBytes: currentArtifactBytes,
            totalExpectedBytes: totalExpectedBytes
        )

        guard let totalExpectedBytes, totalExpectedBytes > 0 else {
            return ModelInstallProgress(
                fractionCompleted: progress,
                completedBytes: nil,
                totalBytes: nil,
                isEstimated: true
            )
        }

        let writtenBytes = min(completedBytes + currentArtifactBytes, totalExpectedBytes)
        return ModelInstallProgress(
            fractionCompleted: progress,
            completedBytes: writtenBytes,
            totalBytes: totalExpectedBytes,
            isEstimated: totalExpectedBytes == self.totalExpectedBytes ? isTotalEstimated : false
        )
    }

    private func progressValue(currentArtifactBytes: Int64, totalExpectedBytes: Int64?) -> Double {
        if let totalExpectedBytes, totalExpectedBytes > 0 {
            let writtenBytes = min(completedBytes + currentArtifactBytes, totalExpectedBytes)
            return min(Double(writtenBytes) / Double(totalExpectedBytes), 1)
        }

        let completedUnit = Double(completedArtifacts)
        let currentUnit = currentArtifactBytes > 0 ? 0.9 : 0
        let totalUnits = Double(max(totalArtifacts, 1))
        return min((completedUnit + currentUnit) / totalUnits, 1)
    }

    private func progressTotalBytes() -> Int64? {
        if let totalExpectedBytes {
            return totalExpectedBytes
        }
        guard artifactExpectedBytes.count == totalArtifacts else {
            return nil
        }
        let total = artifactExpectedBytes.values.reduce(0, +)
        return total > 0 ? total : nil
    }
}

private enum ArtifactCountingMode {
    case absolute
    case relativeToBaseline
}

struct DownloadExpectedBytes: Sendable {
    let bytes: Int64
    let isEstimated: Bool
}

struct DownloadPreflightResult: Sendable {
    let totalExpectedBytes: DownloadExpectedBytes?
    let requiredDownloadBytes: Int64?
    let verifiedExistingBytes: [String: Int64]
    let restoredDownloadedBytes: Int64
}
