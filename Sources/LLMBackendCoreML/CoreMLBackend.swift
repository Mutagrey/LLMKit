import LLMCore
import LLMModelLifecycle
import LLMObservability
import LLMProtocols

public struct CoreMLBackend: ModelBackend, BackendModelUnloading {
    public let backendKind: BackendKind = .coreML
    private let compatibilityChecker: CoreMLModelCompatibilityChecker

    public init(compatibilityChecker: CoreMLModelCompatibilityChecker = CoreMLModelCompatibilityChecker()) {
        self.compatibilityChecker = compatibilityChecker
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        return compatibilityChecker.isCompatible(descriptor) ? .available : .unsupported
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

    public func unloadAllModels() async {}

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

public struct CoreMLModelCompatibilityChecker: Sendable {
    public init() {}

    public func isCompatible(_ descriptor: ModelDescriptor) -> Bool {
        descriptor.backend == .coreML
    }
}

public enum LLMBackendCoreMLNamespace {}
