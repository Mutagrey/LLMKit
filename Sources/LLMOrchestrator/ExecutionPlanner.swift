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
    private let enforcesProcessMemoryBudget: Bool

    public init(
        matcher: CapabilityMatcher = CapabilityMatcher(),
        deviceProfile: DeviceProfile? = DeviceProfileCollector().currentProfile(),
        runtimeConstraints: RuntimeConstraints = RuntimeConstraintsCollector().currentConstraints(),
        memoryGuard: LocalRuntimeMemoryGuard = LocalRuntimeMemoryGuard(),
        enforcesProcessMemoryBudget: Bool = false
    ) {
        self.matcher = matcher
        self.deviceProfile = deviceProfile
        self.runtimeConstraints = runtimeConstraints
        self.memoryGuard = memoryGuard
        self.enforcesProcessMemoryBudget = enforcesProcessMemoryBudget
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

        if shouldEvaluateDeclaredRAM(for: descriptor),
           let minimumRAMGB = descriptor.minimumRAMGB,
           let deviceProfile,
           deviceProfile.physicalMemoryBytes < minimumRAMRejectionThresholdBytes(gigabytes: minimumRAMGB) {
            let currentRAMGB = deviceProfile.physicalMemoryBytes / Self.bytesPerDeclaredGigabyte
            reasons.append("requires \(minimumRAMGB) GB RAM, current device has \(currentRAMGB) GB")
        }

        if requirements.executionMode == .offlineOnly, descriptor.isRemote {
            reasons.append("offline-only requests cannot use remote models")
        }

        if enforcesProcessMemoryBudget,
           let deviceProfile,
           shouldEvaluateLocalRuntimeMemory(for: descriptor),
           let estimate = localRuntimeMemoryEstimate(for: descriptor, requirements: requirements) {
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

    private func shouldEvaluateDeclaredRAM(for descriptor: ModelDescriptor) -> Bool {
        descriptor.backend != .llamaCpp
    }

    private func localRuntimeMemoryEstimate(
        for descriptor: ModelDescriptor,
        requirements: ExecutionRequirements
    ) -> LocalRuntimeMemoryEstimate? {
        let modelMemoryBytes = estimatedModelResidentBytes(for: descriptor)
        let contextMemoryBytes = estimatedContextMemoryBytes(for: descriptor, requirements: requirements)
        guard modelMemoryBytes > 0 || contextMemoryBytes > 0 else {
            return nil
        }
        return LocalRuntimeMemoryEstimate(
            modelMemoryBytes: modelMemoryBytes,
            contextMemoryBytes: contextMemoryBytes
        )
    }

    private func estimatedModelResidentBytes(for descriptor: ModelDescriptor) -> UInt64 {
        if descriptor.backend == .llamaCpp {
            return 0
        }
        guard let estimatedDownloadSizeBytes = descriptor.estimatedDownloadSizeBytes,
              estimatedDownloadSizeBytes > 0 else {
            return 0
        }
        return UInt64(estimatedDownloadSizeBytes)
    }

    private func estimatedContextMemoryBytes(
        for descriptor: ModelDescriptor,
        requirements: ExecutionRequirements
    ) -> UInt64 {
        let contextWindowTokens = estimatedContextWindowTokens(for: descriptor, requirements: requirements)
        guard contextWindowTokens > 0 else {
            return 0
        }
        let result = UInt64(contextWindowTokens).multipliedReportingOverflow(by: 1024)
        return result.overflow ? UInt64.max : result.partialValue
    }

    private func estimatedContextWindowTokens(
        for descriptor: ModelDescriptor,
        requirements: ExecutionRequirements
    ) -> Int {
        let requestedTokens = [
            requirements.budget?.maxInputTokens,
            requirements.budget?.maxOutputTokens
        ]
            .compactMap { $0 }
            .filter { $0 > 0 }
            .reduce(0, +)

        let fallbackTokens = descriptor.contextWindowTokens ?? 0
        let estimatedTokens = requestedTokens > 0 ? requestedTokens : fallbackTokens
        guard let descriptorLimit = descriptor.contextWindowTokens, descriptorLimit > 0 else {
            return estimatedTokens
        }
        return min(estimatedTokens, descriptorLimit)
    }

    private func declaredRAMBytes(gigabytes: Int) -> UInt64 {
        guard gigabytes > 0 else {
            return 0
        }
        let result = UInt64(gigabytes).multipliedReportingOverflow(by: Self.bytesPerDeclaredGigabyte)
        return result.overflow ? UInt64.max : result.partialValue
    }

    private func minimumRAMRejectionThresholdBytes(gigabytes: Int) -> UInt64 {
        let bytes = declaredRAMBytes(gigabytes: gigabytes)
        return bytes - (bytes / 10)
    }

    private static let bytesPerDeclaredGigabyte: UInt64 = 1_000_000_000
}
