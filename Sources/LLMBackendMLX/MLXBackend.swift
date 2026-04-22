import LLMCore
import LLMModelLifecycle
import LLMObservability
import LLMProtocols

public struct MLXBackend: ModelBackend {
    public let backendKind: BackendKind = .mlx
    private let runtimeAvailable: Bool
    private let supportMatrix: MLXModelSupportMatrix

    public init(runtimeAvailable: Bool = false, supportMatrix: MLXModelSupportMatrix = MLXModelSupportMatrix()) {
        self.runtimeAvailable = runtimeAvailable
        self.supportMatrix = supportMatrix
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        guard supportMatrix.supports(descriptor.family) else {
            return .unsupported
        }
        guard runtimeAvailable else {
            return BackendAvailability(status: .unavailable(reason: "MLX runtime is not configured."))
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

public struct MLXModelSupportMatrix: Sendable {
    public init() {}

    public func supports(_ family: ModelFamily) -> Bool {
        switch family {
        case .qwen, .gemma:
            true
        default:
            false
        }
    }
}

public enum LLMBackendMLXNamespace {}
