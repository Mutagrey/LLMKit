import LLMCore

public struct CapabilityMatcher: Sendable {
    public init() {}

    public func model(_ descriptor: ModelDescriptor, satisfies requirements: ExecutionRequirements) -> Bool {
        requirements.requiredCapabilities.isSubset(of: descriptor.capabilities)
    }
}
