import LLMCore
import LLMObservability
import LLMProtocols

public struct FoundationModelsBackend: ModelBackend {
    public let backendKind: BackendKind = .foundationModels
    private let configuredAvailability: FoundationModelsRuntimeAvailability?

    public init(runtimeAvailability: FoundationModelsRuntimeAvailability? = nil) {
        self.configuredAvailability = runtimeAvailability
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        guard descriptor.family == .appleFoundation else {
            return .unsupported
        }
        guard supportsAnyFoundationModelCapability(descriptor.capabilities) else {
            return .unsupported
        }

        let runtimeAvailability = configuredAvailability ?? FoundationModelsRuntimeAvailability.current
        guard runtimeAvailability.isAvailable else {
            return BackendAvailability(status: .unavailable(reason: runtimeAvailability.reason ?? "Foundation Models runtime is unavailable."))
        }
        return .available
    }

    public func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.backend == backendKind
            && model.family == .appleFoundation
            && supportedCapabilities.contains(capability)
            && model.capabilities.contains(capability)
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
            continuation.yield(.started(request.model))
            Task {
                do {
                    try await ensureAvailable(request.model)
                    let text = try await FoundationModelsNativeRuntime.generate(request)
                    if !text.isEmpty {
                        continuation.yield(.delta(text))
                    }
                    continuation.yield(.completed(GenerationResult(text: text, model: request.model)))
                    continuation.finish()
                } catch let error as LLMError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMError.executionFailed(error.localizedDescription))
                }
            }
        }
    }

    public func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started(request.model))
            Task {
                do {
                    try await ensureAvailable(request.model)
                    let text = try await FoundationModelsNativeRuntime.chat(request)
                    if !text.isEmpty {
                        continuation.yield(.delta(text))
                    }
                    let message = ChatMessage(role: .assistant, content: MessageContent(text: text))
                    continuation.yield(.completed(ChatResult(message: message, model: request.model)))
                    continuation.finish()
                } catch let error as LLMError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMError.executionFailed(error.localizedDescription))
                }
            }
        }
    }

    private var supportedCapabilities: Set<ModelCapability> {
        [.chat, .completion, .streaming, .structuredOutput, .summarization, .extraction, .classification, .offline, .lowLatency]
    }

    private func supportsAnyFoundationModelCapability(_ capabilities: Set<ModelCapability>) -> Bool {
        !capabilities.isDisjoint(with: supportedCapabilities)
    }

    private func ensureAvailable(_ descriptor: ModelDescriptor) async throws {
        guard await availability(for: descriptor).status == .available else {
            throw LLMError.unavailable
        }
    }
}

public enum LLMBackendFoundationModelsNamespace {}
