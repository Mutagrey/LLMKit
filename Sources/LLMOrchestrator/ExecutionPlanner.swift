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
    private let memoryGuard: LocalRuntimeMemoryGuard

    public init(
        matcher: CapabilityMatcher = CapabilityMatcher(),
        deviceProfile: DeviceProfile? = DeviceProfileCollector().currentProfile(),
        runtimeConstraints: RuntimeConstraints = RuntimeConstraintsCollector().currentConstraints(),
        memoryGuard: LocalRuntimeMemoryGuard = LocalRuntimeMemoryGuard()
    ) {
        self.matcher = matcher
        self.deviceProfile = deviceProfile
        self.runtimeConstraints = runtimeConstraints
        self.memoryGuard = memoryGuard
    }

    public func plan(models: [ModelDescriptor], requirements: ExecutionRequirements) -> ExecutionPlan {
        let filtered = models.filter { descriptor in
            rejectionReasons(for: descriptor, requirements: requirements).isEmpty
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

    func rejectionReasons(for descriptor: ModelDescriptor, requirements: ExecutionRequirements) -> [String] {
        var reasons: [String] = []

        if !matcher.model(descriptor, satisfies: requirements) {
            let missing = requirements.requiredCapabilities.subtracting(descriptor.capabilities)
            let names = missing.map { String(describing: $0) }.sorted().joined(separator: ", ")
            reasons.append("missing capabilities: \(names)")
        }

        if let minimumRAMGB = descriptor.minimumRAMGB,
           let deviceProfile,
           deviceProfile.physicalMemoryBytes < UInt64(minimumRAMGB) * 1_073_741_824 {
            let currentRAMGB = deviceProfile.physicalMemoryBytes / 1_073_741_824
            reasons.append("requires \(minimumRAMGB) GB RAM, current device has \(currentRAMGB) GB")
        }

        if requirements.executionMode == .offlineOnly, descriptor.isRemote {
            reasons.append("offline-only requests cannot use remote models")
        }

        if let deviceProfile,
           shouldEvaluateLocalRuntimeMemory(for: descriptor),
           let estimate = localRuntimeMemoryEstimate(for: descriptor) {
            let decision = memoryGuard.evaluate(estimate: estimate, profile: deviceProfile)
            if !decision.canLoad {
                reasons.append(decision.reason ?? "insufficient process memory for local runtime")
            }
        }

        return reasons
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

    private func shouldEvaluateLocalRuntimeMemory(for descriptor: ModelDescriptor) -> Bool {
        switch descriptor.backend {
        case .coreML, .mlx, .llamaCpp:
            true
        case .foundationModels, .remote, .executorch, .onnxRuntime, .custom:
            false
        }
    }

    private func localRuntimeMemoryEstimate(for descriptor: ModelDescriptor) -> LocalRuntimeMemoryEstimate? {
        guard let estimatedDownloadSizeBytes = descriptor.estimatedDownloadSizeBytes,
              estimatedDownloadSizeBytes > 0 else {
            return nil
        }
        return LocalRuntimeMemoryEstimate(
            modelMemoryBytes: UInt64(estimatedDownloadSizeBytes),
            contextMemoryBytes: estimatedContextMemoryBytes(for: descriptor)
        )
    }

    private func estimatedContextMemoryBytes(for descriptor: ModelDescriptor) -> UInt64 {
        guard let contextWindowTokens = descriptor.contextWindowTokens, contextWindowTokens > 0 else {
            return 0
        }
        return UInt64(contextWindowTokens) * 1024
    }
}
