import LLMCore
import LLMDeviceProfiling

public struct ExecutionPlan: Hashable, Sendable {
    public let candidates: [ModelDescriptor]
    public let requirements: ExecutionRequirements

    public init(candidates: [ModelDescriptor], requirements: ExecutionRequirements) {
        self.candidates = candidates
        self.requirements = requirements
    }
}

public struct ExecutionPlanner: Sendable {
    private let matcher: CapabilityMatcher
    private let deviceProfile: DeviceProfile?
    private let runtimeConstraints: RuntimeConstraints

    public init(
        matcher: CapabilityMatcher = CapabilityMatcher(),
        deviceProfile: DeviceProfile? = DeviceProfileCollector().currentProfile(),
        runtimeConstraints: RuntimeConstraints = RuntimeConstraintsCollector().currentConstraints()
    ) {
        self.matcher = matcher
        self.deviceProfile = deviceProfile
        self.runtimeConstraints = runtimeConstraints
    }

    public func plan(models: [ModelDescriptor], requirements: ExecutionRequirements) -> ExecutionPlan {
        let filtered = models.filter { descriptor in
            guard matcher.model(descriptor, satisfies: requirements) else {
                return false
            }
            guard meetsDeviceRequirements(descriptor) else {
                return false
            }
            switch requirements.executionMode {
            case .offlineOnly:
                return !descriptor.isRemote
            case .preferOffline:
                return true
            case .hybrid, .remoteAllowed:
                return true
            }
        }
        let sorted = filtered.sorted { lhs, rhs in
            if requirements.executionMode == .preferOffline, lhs.isRemote != rhs.isRemote {
                return !lhs.isRemote
            }
            if requirements.qualityTier == .fast,
               footprintScore(lhs) != footprintScore(rhs) {
                return footprintScore(lhs) < footprintScore(rhs)
            }
            if requirements.qualityTier == .best,
               qualityScore(lhs) != qualityScore(rhs) {
                return qualityScore(lhs) > qualityScore(rhs)
            }
            if runtimeConstraints.isLowPowerPreferred,
               footprintScore(lhs) != footprintScore(rhs) {
                return footprintScore(lhs) < footprintScore(rhs)
            }
            return lhs.displayName < rhs.displayName
        }
        return ExecutionPlan(candidates: sorted, requirements: requirements)
    }

    private func meetsDeviceRequirements(_ descriptor: ModelDescriptor) -> Bool {
        if let minimumRAMGB = descriptor.minimumRAMGB,
           let deviceProfile,
           deviceProfile.physicalMemoryBytes < UInt64(minimumRAMGB) * 1_073_741_824 {
            return false
        }

        if let minimumFreeDiskGB = descriptor.minimumFreeDiskGB,
           let availableFreeDiskGB = runtimeConstraints.minimumFreeDiskGB,
           availableFreeDiskGB < minimumFreeDiskGB {
            return false
        }

        return true
    }

    private func footprintScore(_ descriptor: ModelDescriptor) -> Int64 {
        let ramComponent = Int64(descriptor.minimumRAMGB ?? 0) * 1_000_000_000
        let sizeComponent = descriptor.estimatedDownloadSizeBytes ?? 0
        return ramComponent + sizeComponent
    }

    private func qualityScore(_ descriptor: ModelDescriptor) -> Int64 {
        let contextComponent = Int64(descriptor.contextWindowTokens ?? 0) * 1_000_000
        let ramComponent = Int64(descriptor.minimumRAMGB ?? 0) * 1_000
        return contextComponent + ramComponent + (descriptor.supportsStructuredOutput ? 1 : 0)
    }
}
