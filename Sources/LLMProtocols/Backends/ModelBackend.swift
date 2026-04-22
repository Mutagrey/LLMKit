import LLMCore

public protocol ModelBackend: Sendable {
    var backendKind: BackendKind { get }

    func availability(for descriptor: ModelDescriptor) async -> BackendAvailability
    func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool
    func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle
    func unloadModel(_ handle: LoadedModelHandle) async
    func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error>
    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error>
}
