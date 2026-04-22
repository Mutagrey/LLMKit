import LLMCore
import LLMObservability
import LLMProtocols

public struct FoundationModelsRuntimeAvailability: Hashable, Sendable {
    public let isAvailable: Bool
    public let reason: String?

    public init(isAvailable: Bool, reason: String? = nil) {
        self.isAvailable = isAvailable
        self.reason = reason
    }
}

public struct FoundationModelsBackend: ModelBackend {
    public let backendKind: BackendKind = .foundationModels
    private let runtimeAvailability: FoundationModelsRuntimeAvailability

    public init(runtimeAvailability: FoundationModelsRuntimeAvailability = FoundationModelsRuntimeAvailability(isAvailable: false, reason: "Foundation Models runtime is not configured.")) {
        self.runtimeAvailability = runtimeAvailability
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        guard runtimeAvailability.isAvailable else {
            return BackendAvailability(status: .unavailable(reason: runtimeAvailability.reason ?? "Foundation Models runtime is unavailable."))
        }
        return .available
    }

    public func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.backend == backendKind && model.capabilities.contains(capability)
    }

    public func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle {
        guard await availability(for: descriptor).status == .available else {
            throw LLMError.unavailable
        }
        return LoadedModelHandle(id: descriptor.id, backend: descriptor.backend)
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
