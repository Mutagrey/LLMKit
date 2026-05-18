import LLMCore

public struct LlamaCppModelSupportMatrix: Sendable {
    public init() {}

    public func supports(_ family: ModelFamily) -> Bool {
        switch family {
        case .llama:
            true
        default:
            false
        }
    }

    public func supports(_ descriptor: ModelDescriptor) -> Bool {
        supports(descriptor.family) &&
            descriptor.capabilities.isDisjoint(with: unsupportedCapabilities) &&
            descriptorHasGGUFArtifact(descriptor)
    }

    private let unsupportedCapabilities: Set<ModelCapability> = [
        .multimodalInput,
        .structuredOutput,
        .toolCalling,
        .embeddings
    ]

    private func descriptorHasGGUFArtifact(_ descriptor: ModelDescriptor) -> Bool {
        descriptor.source?.artifacts.contains { artifact in
            artifact.relativePath.lowercased().hasSuffix(".gguf")
        } == true
    }
}
