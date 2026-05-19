import Foundation
import LLMCore
import LLMModelLifecycle
import LLMObservability
import LLMProtocols
#if os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#endif

public struct MLXBackend: ModelBackend, BackendChatSessionResetting, BackendModelUnloading {
    public let backendKind: BackendKind = .mlx
    private let runtime: (any MLXRuntime)?
    private let supportMatrix: MLXModelSupportMatrix
    private let metricsSink: (any MetricsSink)?

    public init(
        runtimeAvailable: Bool = false,
        modelRootDirectory: URL? = ModelArtifactLocationResolver.defaultRootDirectory(),
        supportMatrix: MLXModelSupportMatrix = MLXModelSupportMatrix(),
        memoryPolicy: MLXMemoryPolicy = .default,
        metricsSink: (any MetricsSink)? = nil
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
        self.metricsSink = metricsSink
    }

    init(
        runtime: any MLXRuntime,
        supportMatrix: MLXModelSupportMatrix = MLXModelSupportMatrix(),
        metricsSink: (any MetricsSink)? = nil
    ) {
        self.runtime = runtime
        self.supportMatrix = supportMatrix
        self.metricsSink = metricsSink
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
        let startedAt = Date()
        let memoryBeforeLoadBytes = Self.availableProcessMemoryBytes()
        try await runtime.loadModel(descriptor)
        await recordRuntimeMetrics(
            name: "mlx.model_load.completed",
            metrics: LLMRuntimeMetrics(
                modelLoadTimeMilliseconds: Self.elapsedMilliseconds(since: startedAt),
                memoryBeforeLoadBytes: memoryBeforeLoadBytes,
                memoryAfterLoadBytes: Self.availableProcessMemoryBytes()
            )
        )
        return LoadedModelHandle(id: descriptor.id, backend: descriptor.backend)
    }

    public func unloadModel(_ handle: LoadedModelHandle) async {
        await runtime?.unload(modelID: handle.id)
    }

    public func unloadAllModels() async {
        await runtime?.unloadAll()
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
            _ = try await loadModel(model)
            let stream = try await runtime.stream(
                prompt: prompt,
                model: model,
                maxTokens: maxTokens
            )
            let output = try await collectSanitizedText(from: stream, onDelta: onDelta)
            await runtime.finishGenerationCleanup()
            await recordRuntimeMetrics(
                name: "mlx.generation.completed",
                metrics: output.metrics(memoryAfterGenerationBytes: Self.availableProcessMemoryBytes())
            )
            return output.text
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
            _ = try await loadModel(model)
            let stream = try await runtime.stream(
                messages: messages,
                sessionID: sessionID,
                model: model,
                maxTokens: maxTokens
            )
            let output = try await collectSanitizedText(from: stream, onDelta: onDelta)
            await runtime.finishGenerationCleanup()
            await recordRuntimeMetrics(
                name: "mlx.generation.completed",
                metrics: output.metrics(memoryAfterGenerationBytes: Self.availableProcessMemoryBytes())
            )
            return output.text
        } catch {
            await runtime.finishGenerationCleanup()
            throw error
        }
    }

    private func collectSanitizedText(
        from stream: AsyncThrowingStream<MLXRuntimeGenerationEvent, Error>,
        onDelta: (String) -> Void
    ) async throws -> CollectedRuntimeText {
        let startedAt = Date()
        var sanitizer = MLXStreamOutputSanitizer()
        var output = ""
        var timeToFirstTokenMilliseconds: Int?
        var generationTimeMilliseconds: Int?
        var tokensPerSecond: Double?

        for try await event in stream {
            if let eventGenerationTimeMilliseconds = event.generationTimeMilliseconds {
                generationTimeMilliseconds = eventGenerationTimeMilliseconds
            }
            if let eventTokensPerSecond = event.tokensPerSecond {
                tokensPerSecond = eventTokensPerSecond
            }
            guard let delta = event.text else {
                continue
            }
            let outcome = sanitizer.append(delta)
            if !outcome.visibleText.isEmpty {
                if timeToFirstTokenMilliseconds == nil {
                    timeToFirstTokenMilliseconds = Self.elapsedMilliseconds(since: startedAt)
                }
                output += outcome.visibleText
                onDelta(outcome.visibleText)
            }
            if outcome.shouldStop {
                break
            }
        }

        let trailingText = sanitizer.finish()
        if !trailingText.isEmpty {
            if timeToFirstTokenMilliseconds == nil {
                timeToFirstTokenMilliseconds = Self.elapsedMilliseconds(since: startedAt)
            }
            output += trailingText
            onDelta(trailingText)
        }

        return CollectedRuntimeText(
            text: output,
            timeToFirstTokenMilliseconds: timeToFirstTokenMilliseconds,
            generationTimeMilliseconds: generationTimeMilliseconds ?? Self.elapsedMilliseconds(since: startedAt),
            tokensPerSecond: tokensPerSecond
        )
    }

    private func recordRuntimeMetrics(name: String, metrics: LLMRuntimeMetrics) async {
        guard let metricsSink else {
            return
        }
        await metricsSink.record(TelemetryEvent(name: name, metadata: metrics.sanitizedMetadata()))
    }

    private static func elapsedMilliseconds(since start: Date) -> Int {
        max(0, Int((Date().timeIntervalSince(start) * 1_000).rounded()))
    }

    private static func availableProcessMemoryBytes() -> UInt64? {
        #if os(iOS) || os(tvOS) || os(watchOS)
        UInt64(os_proc_available_memory())
        #else
        nil
        #endif
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

private struct CollectedRuntimeText {
    let text: String
    let timeToFirstTokenMilliseconds: Int?
    let generationTimeMilliseconds: Int?
    let tokensPerSecond: Double?

    func metrics(memoryAfterGenerationBytes: UInt64?) -> LLMRuntimeMetrics {
        LLMRuntimeMetrics(
            timeToFirstTokenMilliseconds: timeToFirstTokenMilliseconds,
            generationTimeMilliseconds: generationTimeMilliseconds,
            tokensPerSecond: tokensPerSecond,
            memoryAfterGenerationBytes: memoryAfterGenerationBytes
        )
    }
}
