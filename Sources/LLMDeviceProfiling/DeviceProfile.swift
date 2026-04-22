import Foundation

public struct DeviceProfile: Hashable, Sendable {
    public let operatingSystemVersion: String
    public let physicalMemoryBytes: UInt64
    public let processorCount: Int

    public init(operatingSystemVersion: String, physicalMemoryBytes: UInt64, processorCount: Int) {
        self.operatingSystemVersion = operatingSystemVersion
        self.physicalMemoryBytes = physicalMemoryBytes
        self.processorCount = processorCount
    }
}

public struct RuntimeConstraints: Hashable, Sendable {
    public let isLowPowerPreferred: Bool
    public let minimumFreeDiskGB: Int?

    public init(isLowPowerPreferred: Bool = false, minimumFreeDiskGB: Int? = nil) {
        self.isLowPowerPreferred = isLowPowerPreferred
        self.minimumFreeDiskGB = minimumFreeDiskGB
    }
}

public struct DeviceProfileCollector: Sendable {
    public init() {}

    public func currentProfile() -> DeviceProfile {
        let processInfo = ProcessInfo.processInfo
        return DeviceProfile(
            operatingSystemVersion: processInfo.operatingSystemVersionString,
            physicalMemoryBytes: processInfo.physicalMemory,
            processorCount: processInfo.processorCount
        )
    }
}
