import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#endif

public struct DeviceProfile: Hashable, Sendable {
    public let operatingSystemVersion: String
    public let physicalMemoryBytes: UInt64
    public let processorCount: Int
    public let availableProcessMemoryBytes: UInt64?

    public init(
        operatingSystemVersion: String,
        physicalMemoryBytes: UInt64,
        processorCount: Int,
        availableProcessMemoryBytes: UInt64? = nil
    ) {
        self.operatingSystemVersion = operatingSystemVersion
        self.physicalMemoryBytes = physicalMemoryBytes
        self.processorCount = processorCount
        self.availableProcessMemoryBytes = availableProcessMemoryBytes
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
            processorCount: processInfo.processorCount,
            availableProcessMemoryBytes: Self.availableProcessMemoryBytes()
        )
    }

    private static func availableProcessMemoryBytes() -> UInt64? {
        #if os(iOS) || os(tvOS) || os(watchOS)
        UInt64(os_proc_available_memory())
        #else
        nil
        #endif
    }
}
