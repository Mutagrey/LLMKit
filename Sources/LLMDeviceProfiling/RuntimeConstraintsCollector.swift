import Foundation

public struct RuntimeConstraintsCollector: Sendable {
    public init() {}

    public func currentConstraints(volumeURL: URL? = nil) -> RuntimeConstraints {
        RuntimeConstraints(
            isLowPowerPreferred: ProcessInfo.processInfo.isLowPowerModeEnabled,
            minimumFreeDiskGB: availableFreeDiskGB(at: volumeURL)
        )
    }

    private func availableFreeDiskGB(at volumeURL: URL?) -> Int? {
        let targetURL = volumeURL ?? FileManager.default.homeDirectoryForCurrentUser
        guard let values = try? targetURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage else {
            return nil
        }

        let gigabyte = Double(1_073_741_824)
        return max(Int((Double(bytes) / gigabyte).rounded(.down)), 0)
    }
}
