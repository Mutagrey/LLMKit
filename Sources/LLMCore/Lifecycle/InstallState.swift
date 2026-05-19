import Foundation

public enum DownloadState: Hashable, Codable, Sendable {
    case notStarted
    case downloading(progress: Double)
    case downloaded
    case failed(String)
}

public enum InstallState: Hashable, Codable, Sendable {
    case notInstalled
    case downloading(progress: Double)
    case paused(progress: Double)
    case downloaded
    case verifying
    case compiling
    case ready
    case warming
    case active
    case failed(String)
    case evicted(EvictionReason)
}

public enum WarmupState: Hashable, Codable, Sendable {
    case notStarted
    case warming
    case warm
    case failed(String)
}

public enum EvictionReason: Hashable, Codable, Sendable {
    case storagePressure
    case userRequested
    case policy
    case unknown
}

public struct ModelInstallProgress: Hashable, Codable, Sendable {
    public let fractionCompleted: Double
    public let completedBytes: Int64?
    public let totalBytes: Int64?
    public let isEstimated: Bool

    public init(
        fractionCompleted: Double,
        completedBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        isEstimated: Bool
    ) {
        self.fractionCompleted = fractionCompleted
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
        self.isEstimated = isEstimated
    }
}

public struct InstalledModelRecord: Hashable, Codable, Sendable, Identifiable {
    public var id: ModelID { descriptor.id }

    public let descriptor: ModelDescriptor
    public let installState: InstallState
    public let installedAt: Date?

    public init(descriptor: ModelDescriptor, installState: InstallState, installedAt: Date? = nil) {
        self.descriptor = descriptor
        self.installState = installState
        self.installedAt = installedAt
    }
}

public struct ModelStorageUsage: Hashable, Codable, Sendable {
    public let totalBytes: Int64
    public let modelBytes: [ModelID: Int64]
    public let availableBytes: Int64?
    public let capacityBytes: Int64?

    public init(
        totalBytes: Int64,
        modelBytes: [ModelID: Int64] = [:],
        availableBytes: Int64? = nil,
        capacityBytes: Int64? = nil
    ) {
        self.totalBytes = totalBytes
        self.modelBytes = modelBytes
        self.availableBytes = availableBytes
        self.capacityBytes = capacityBytes
    }

    public static let empty = ModelStorageUsage(totalBytes: 0)
}

public enum ModelInstallEvent: Equatable, Sendable {
    case stateChanged(ModelID, InstallState)
    case progress(ModelID, Double)
    case progressDetail(ModelID, ModelInstallProgress)
    case completed(InstalledModelRecord)
    case failed(ModelID, LLMError)
}
