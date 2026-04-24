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
        let targetURL: URL
        if let volumeURL {
            targetURL = volumeURL
        } else {
            // Use the app's documents directory as a representative volume URL on iOS
            targetURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        }
        guard let values = try? targetURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage else {
            return nil
        }

        let gigabyte = Double(1_073_741_824)
        return max(Int((Double(bytes) / gigabyte).rounded(.down)), 0)
    }
}
