import Foundation
import LLMCore
import LLMModelLifecycle
import LLMObservability
import LLMProtocols

public struct MLXBackend: ModelBackend, BackendChatSessionResetting {
    public let backendKind: BackendKind = .mlx
    private let runtime: MLXLocalRuntime?
    private let supportMatrix: MLXModelSupportMatrix

    public init(
        runtimeAvailable: Bool = false,
        modelRootDirectory: URL? = ModelArtifactLocationResolver.defaultRootDirectory(),
        supportMatrix: MLXModelSupportMatrix = MLXModelSupportMatrix(),
        memoryPolicy: MLXMemoryPolicy = .default
    ) {
        if runtimeAvailable, Self.canCreateLocalRuntime, let modelRootDirectory {
            self.runtime = MLXLocalRuntime(
                modelRootDirectory: modelRootDirectory,
                memoryPolicy: memoryPolicy
            )
        } else {
            self.runtime = nil
        }
        self.supportMatrix = supportMatrix
    }

    private static var canCreateLocalRuntime: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        guard supportMatrix.supports(descriptor.family) else {
            return .unsupported
        }
        guard supportMatrix.supports(descriptor) else {
            return BackendAvailability(status: .unavailable(reason: "This MLX adapter currently supports text-only local models."))
        }
        guard let runtime else {
            return BackendAvailability(status: .unavailable(reason: "MLX runtime is not configured."))
        }
        guard await runtime.hasLocalFiles(for: descriptor) else {
            return BackendAvailability(status: .requiresInstall)
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
        guard let runtime else {
            throw LLMError.unavailable
        }
        try await runtime.loadContainer(for: descriptor)
        return LoadedModelHandle(id: descriptor.id, backend: descriptor.backend)
    }

    public func unloadModel(_ handle: LoadedModelHandle) async {
        await runtime?.unload(modelID: handle.id)
    }

    public func updateMemoryPolicy(_ memoryPolicy: MLXMemoryPolicy) async {
        await runtime?.updateMemoryPolicy(memoryPolicy)
    }

    public func resetChatSession(modelID: ModelID, sessionID: SessionID) async {
        await runtime?.resetChatSession(modelID: modelID, sessionID: sessionID)
    }

    public func resetChatSessions(sessionID: SessionID) async {
        await runtime?.resetChatSessions(sessionID: sessionID)
    }

    public func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard runtime != nil else {
                        throw LLMError.unavailable
                    }
                    continuation.yield(.started(request.model))
                    let output = try await streamSanitizedText(
                        prompt: request.request.renderedPrompt,
                        model: request.model,
                        maxTokens: request.request.requirements.budget?.maxOutputTokens,
                        onDelta: { continuation.yield(.delta($0)) }
                    )
                    continuation.yield(.completed(GenerationResult(text: output, model: request.model)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapRuntimeError(error))
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard runtime != nil else {
                        throw LLMError.unavailable
                    }
                    continuation.yield(.started(request.model))
                    let output = try await streamSanitizedChat(
                        messages: request.request.messages,
                        sessionID: request.request.sessionID,
                        model: request.model,
                        maxTokens: request.request.requirements.budget?.maxOutputTokens,
                        onDelta: { continuation.yield(.delta($0)) }
                    )
                    await runtime?.recordChatCompletion(
                        modelID: request.model.id,
                        sessionID: request.request.sessionID,
                        requestMessageCount: request.request.messages.count
                    )
                    let message = ChatMessage(role: .assistant, content: MessageContent(text: output))
                    continuation.yield(.completed(ChatResult(message: message, model: request.model)))
                    continuation.finish()
                } catch {
                    if let sessionID = request.request.sessionID {
                        await resetChatSession(modelID: request.model.id, sessionID: sessionID)
                    }
                    continuation.finish(throwing: mapRuntimeError(error))
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func streamSanitizedText(
        prompt: String,
        model: ModelDescriptor,
        maxTokens: Int?,
        onDelta: (String) -> Void
    ) async throws -> String {
        guard let runtime else {
            throw LLMError.unavailable
        }

        do {
            let stream = try await runtime.stream(
                prompt: prompt,
                model: model,
                maxTokens: maxTokens
            )
            let output = try await collectSanitizedText(from: stream, onDelta: onDelta)
            await runtime.finishGenerationCleanup()
            return output
        } catch {
            await runtime.finishGenerationCleanup()
            throw error
        }
    }

    private func streamSanitizedChat(
        messages: [ChatMessage],
        sessionID: SessionID?,
        model: ModelDescriptor,
        maxTokens: Int?,
        onDelta: (String) -> Void
    ) async throws -> String {
        guard let runtime else {
            throw LLMError.unavailable
        }

        do {
            let stream = try await runtime.stream(
                messages: messages,
                sessionID: sessionID,
                model: model,
                maxTokens: maxTokens
            )
            let output = try await collectSanitizedText(from: stream, onDelta: onDelta)
            await runtime.finishGenerationCleanup()
            return output
        } catch {
            await runtime.finishGenerationCleanup()
            throw error
        }
    }

    private func collectSanitizedText(
        from stream: AsyncThrowingStream<String, Error>,
        onDelta: (String) -> Void
    ) async throws -> String {
        var sanitizer = MLXStreamOutputSanitizer()
        var output = ""
        for try await delta in stream {
            let outcome = sanitizer.append(delta)
            if !outcome.visibleText.isEmpty {
                output += outcome.visibleText
                onDelta(outcome.visibleText)
            }
            if outcome.shouldStop {
                break
            }
        }

        let trailingText = sanitizer.finish()
        if !trailingText.isEmpty {
            output += trailingText
            onDelta(trailingText)
        }

        return output
    }

    private func mapRuntimeError(_ error: Error) -> LLMError {
        if let llmError = error as? LLMError {
            return llmError
        }
        if error is CancellationError {
            return .cancelled
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError {
            return .executionFailed("Model files are incomplete or missing. Re-download the model.")
        }
        return .executionFailed(String(describing: error))
    }
}

public enum LLMBackendMLXNamespace {}
