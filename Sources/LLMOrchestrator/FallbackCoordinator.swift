import LLMCore

public struct FallbackCoordinator: Sendable {
    public init() {}

    public func shouldFallback(after error: Error) -> Bool {
        if error is CancellationError {
            return false
        }
        guard let llmError = error as? LLMError else {
            return true
        }
        switch llmError {
        case .cancelled, .unsupportedCapabilities:
            return false
        case .unavailable, .modelNotInstalled, .downloadFailed, .verificationFailed, .compilationFailed, .executionFailed, .toolExecutionFailed, .invalidStructuredOutput:
            return true
        }
    }

    public func nextCandidate(after failed: ModelDescriptor, in plan: ExecutionPlan) -> ModelDescriptor? {
        guard let index = plan.candidates.firstIndex(of: failed) else {
            return plan.candidates.first
        }
        return plan.candidates.dropFirst(index + 1).first
    }
}
