import LLMCore

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

    public init(matcher: CapabilityMatcher = CapabilityMatcher()) {
        self.matcher = matcher
    }

    public func plan(models: [ModelDescriptor], requirements: ExecutionRequirements) -> ExecutionPlan {
        let filtered = models.filter { descriptor in
            guard matcher.model(descriptor, satisfies: requirements) else {
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
            return lhs.displayName < rhs.displayName
        }
        return ExecutionPlan(candidates: sorted, requirements: requirements)
    }
}
