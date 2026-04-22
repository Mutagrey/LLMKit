import LLMCore

public struct FallbackCoordinator: Sendable {
    public init() {}

    public func nextCandidate(after failed: ModelDescriptor, in plan: ExecutionPlan) -> ModelDescriptor? {
        guard let index = plan.candidates.firstIndex(of: failed) else {
            return plan.candidates.first
        }
        return plan.candidates.dropFirst(index + 1).first
    }
}
