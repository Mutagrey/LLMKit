import LLMCore
import LLMObservability
import LLMProtocols

public struct FoundationModelsBackend: ModelBackend {
    public let backendKind: BackendKind = .foundationModels

    public init() {}

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        descriptor.backend == backendKind ? .unsupported : .unsupported
    }

    public func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.backend == backendKind && model.capabilities.contains(capability)
    }

    public func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle {
        throw LLMError.unavailable
    }

    public func unloadModel(_ handle: LoadedModelHandle) async {}

    public func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.unavailable)
        }
    }

    public func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.unavailable)
        }
    }
}

public enum LLMBackendFoundationModelsNamespace {}
