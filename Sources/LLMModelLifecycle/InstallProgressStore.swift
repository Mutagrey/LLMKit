import Foundation
import LLMCore

struct InstallProgressStore: Sendable {
    let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    func storageUsage(for modelID: ModelID) throws -> Int64 {
        let directory = modelDirectory(for: modelID)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return 0
        }

        return try restoredDownloadedBytes(in: directory)
    }

    func restoredState(for modelID: ModelID) throws -> InstallState? {
        let directory = modelDirectory(for: modelID)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return nil
        }

        if let snapshot = progressSnapshot(in: directory),
           snapshot.completedBytes > 0 || snapshot.fractionCompleted > 0 {
            return .paused(progress: DownloadProgressTracker.normalizedFraction(snapshot.fractionCompleted))
        }

        return try restoredDownloadedBytes(in: directory) > 0 ? .paused(progress: 0) : nil
    }

    func restoredDownloadedBytes(for modelID: ModelID) throws -> Int64 {
        let directory = modelDirectory(for: modelID)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return 0
        }

        return try restoredDownloadedBytes(in: directory)
    }

    func store(modelID: ModelID, progress: ModelInstallProgress) throws {
        guard let completedBytes = progress.completedBytes, completedBytes > 0 else {
            return
        }

        let directory = modelDirectory(for: modelID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = InstallProgressSnapshot(
            completedBytes: completedBytes,
            totalBytes: progress.totalBytes,
            fractionCompleted: progress.fractionCompleted,
            isEstimated: progress.isEstimated
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: progressSnapshotURL(in: directory), options: [.atomic])
    }

    func remove(modelID: ModelID) throws {
        let directory = modelDirectory(for: modelID)
        let url = progressSnapshotURL(in: directory)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func diskUsageSnapshot() throws -> (availableBytes: Int64?, capacityBytes: Int64?) {
        let probeURL = Self.existingVolumeProbeURL(for: rootDirectory)
        let values = try probeURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey
        ])
        return (
            values.volumeAvailableCapacityForImportantUsage ?? values.volumeAvailableCapacity.map(Int64.init),
            values.volumeTotalCapacity.map(Int64.init)
        )
    }

    private func modelDirectory(for modelID: ModelID) -> URL {
        ModelArtifactLocationResolver(rootDirectory: rootDirectory)
            .modelDirectory(for: modelID)
    }

    private func restoredDownloadedBytes(in directory: URL) throws -> Int64 {
        let artifactBytes = try storageUsage(in: directory)
        let snapshotBytes = progressSnapshot(in: directory).map { max($0.completedBytes, 0) } ?? 0
        let resumeBytes = try resumeCacheDownloadedBytes(in: directory)
        return max(artifactBytes, snapshotBytes, resumeBytes)
    }

    private func storageUsage(in directory: URL) throws -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard Self.isUserFacingArtifactFile(fileURL) else {
                continue
            }
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func resumeCacheDownloadedBytes(in directory: URL) throws -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.hasSuffix(".resumeData") else {
                continue
            }
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }
            total += Self.resumeCacheDownloadedBytes(at: fileURL)
        }
        return total
    }

    private func progressSnapshot(in directory: URL) -> InstallProgressSnapshot? {
        let url = progressSnapshotURL(in: directory)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(InstallProgressSnapshot.self, from: data)
    }

    private func progressSnapshotURL(in directory: URL) -> URL {
        directory.appendingPathComponent(".llmkit-install-progress.json")
    }

    private static func resumeCacheDownloadedBytes(at fileURL: URL) -> Int64 {
        guard
            let data = try? Data(contentsOf: fileURL),
            let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else {
            return 0
        }
        return resumeCacheDownloadedBytes(in: propertyList)
    }

    private static func resumeCacheDownloadedBytes(in value: Any) -> Int64 {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let string = value as? String {
            return Int64(string) ?? byteRangeUpperBound(in: string)
        }
        if let dictionary = value as? [String: Any] {
            var best: Int64 = 0
            for (key, nestedValue) in dictionary {
                if key.localizedCaseInsensitiveContains("BytesReceived") ||
                    key.localizedCaseInsensitiveContains("BytesWritten") {
                    best = max(best, resumeCacheDownloadedBytes(in: nestedValue))
                }
            }
            return best
        }
        if let array = value as? [Any] {
            return array.map(resumeCacheDownloadedBytes(in:)).max() ?? 0
        }
        return 0
    }

    private static func byteRangeUpperBound(in string: String) -> Int64 {
        let numbers = string
            .split { !$0.isNumber }
            .compactMap { Int64($0) }
        return numbers.max() ?? 0
    }

    private static func isUserFacingArtifactFile(_ fileURL: URL) -> Bool {
        let name = fileURL.lastPathComponent
        if name.hasPrefix(".") || name.hasSuffix(".resumeData") {
            return false
        }
        return true
    }

    private static func existingVolumeProbeURL(for url: URL) -> URL {
        var probeURL = url
        while !FileManager.default.fileExists(atPath: probeURL.path) {
            let parent = probeURL.deletingLastPathComponent()
            guard parent.path != probeURL.path else {
                return FileManager.default.temporaryDirectory
            }
            probeURL = parent
        }
        return probeURL
    }
}

private struct InstallProgressSnapshot: Codable, Sendable {
    let completedBytes: Int64
    let totalBytes: Int64?
    let fractionCompleted: Double
    let isEstimated: Bool
}
