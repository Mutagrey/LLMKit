import Foundation

public protocol ModelInstallDiskSpaceProviding: Sendable {
    func availableBytes(at url: URL) throws -> Int64?
}

public struct FileSystemModelInstallDiskSpaceProvider: ModelInstallDiskSpaceProviding {
    public init() {}

    public func availableBytes(at url: URL) throws -> Int64? {
        let probeURL = existingVolumeProbeURL(for: url)
        let values = try probeURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])

        if let importantUsageBytes = values.volumeAvailableCapacityForImportantUsage {
            return importantUsageBytes
        }
        if let availableBytes = values.volumeAvailableCapacity {
            return Int64(availableBytes)
        }
        return nil
    }

    private func existingVolumeProbeURL(for url: URL) -> URL {
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
