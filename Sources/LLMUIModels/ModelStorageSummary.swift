import Foundation

public struct ModelStorageSummary: Hashable, Sendable {
    public let downloadedModelCount: Int
    public let totalModelCount: Int
    public let installedBytes: Int64
    public let partialBytes: Int64
    public let availableBytes: Int64?
    public let capacityBytes: Int64?

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
}
