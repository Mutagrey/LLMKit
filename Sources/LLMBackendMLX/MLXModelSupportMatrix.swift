import LLMCore

public struct MLXModelSupportMatrix: Sendable {
    public init() {}

    public func supports(_ family: ModelFamily) -> Bool {
        switch family {
        case .qwen, .gemma, .llama, .mistral:
            true
        default:
            false
        }
    }

    public func supports(_ descriptor: ModelDescriptor) -> Bool {
        supports(descriptor.family)
    }
}
