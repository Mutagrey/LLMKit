import Foundation
import LLMCore
import LLMModelLifecycle
import LLMProtocols
#if os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#endif

public struct LlamaCppBackend: ModelBackend, BackendChatSessionResetting, BackendModelUnloading {
    public let backendKind: BackendKind = .llamaCpp
    private let runtime: (any LlamaCppRuntime)?
    private let supportMatrix: LlamaCppModelSupportMatrix
    private let promptFormatter: LlamaCppPromptFormatter
    private let metricsSink: (any MetricsSink)?

    public init(
        runtimeAvailable: Bool = false,
        modelRootDirectory: URL? = ModelArtifactLocationResolver.defaultRootDirectory(),
        supportMatrix: LlamaCppModelSupportMatrix = LlamaCppModelSupportMatrix(),
        configuration: LlamaCppRuntimeConfiguration = .default,
        metricsSink: (any MetricsSink)? = nil
    ) {
        if runtimeAvailable, let modelRootDirectory {
            self.runtime = LlamaCppLocalRuntime(
                modelRootDirectory: modelRootDirectory,
                configuration: configuration
            )
        } else {
            self.runtime = nil
        }
        self.supportMatrix = supportMatrix
        self.promptFormatter = LlamaCppPromptFormatter()
        self.metricsSink = metricsSink
    }

    init(
        runtime: any LlamaCppRuntime,
        supportMatrix: LlamaCppModelSupportMatrix = LlamaCppModelSupportMatrix(),
        promptFormatter: LlamaCppPromptFormatter = LlamaCppPromptFormatter(),
        metricsSink: (any MetricsSink)? = nil
    ) {
        self.runtime = runtime
        self.supportMatrix = supportMatrix
        self.promptFormatter = promptFormatter
        self.metricsSink = metricsSink
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        guard supportMatrix.supports(descriptor.family) else {
            return .unsupported
        }
        guard supportMatrix.supports(descriptor) else {
            return BackendAvailability(status: .unavailable(reason: "llama.cpp v1 supports Llama text GGUF models only."))
        }
        guard let runtime else {
            return BackendAvailability(status: .unavailable(reason: "llama.cpp native runtime is not configured."))
        }
        guard await runtime.hasLocalFiles(for: descriptor) else {
            return BackendAvailability(status: .requiresInstall)
        }
        guard await runtime.nativeRuntimeAvailable() else {
            return BackendAvailability(status: .unavailable(reason: "llama.cpp native runtime is not linked. Add llama.xcframework to enable GGUF execution."))
        }
        return .available
    }

    public func runtimeReport() async -> LlamaCppRuntimeReport? {
        guard let runtime else {
            return nil
        }
        return await runtime.runtimeReport()
    }

    public func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.backend == backendKind &&
            model.capabilities.contains(capability) &&
            supportMatrix.supports(model)
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
            name: "llamaCpp.model_load.completed",
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
                    continuation.yield(.started(request.model))
                    let output = try await collectStreamedText(
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
                    let prompt = try promptFormatter.prompt(from: request.request.messages)
                    continuation.yield(.started(request.model))
                    let output = try await collectStreamedText(
                        prompt: prompt,
                        model: request.model,
                        maxTokens: request.request.requirements.budget?.maxOutputTokens,
                        onDelta: { continuation.yield(.delta($0)) }
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

    private func collectStreamedText(
        prompt: String,
        model: ModelDescriptor,
        maxTokens: Int?,
        onDelta: (String) -> Void
    ) async throws -> String {
        guard let runtime else {
            throw LLMError.unavailable
        }

        _ = try await loadModel(model)
        let startedAt = Date()
        let stream = try await runtime.stream(prompt: prompt, model: model, maxTokens: maxTokens)
        var output = ""
        var generatedTokenCount = 0
        var timeToFirstTokenMilliseconds: Int?
        for try await event in stream {
            try Task.checkCancellation()
            if timeToFirstTokenMilliseconds == nil {
                timeToFirstTokenMilliseconds = Self.elapsedMilliseconds(since: startedAt)
            }
            generatedTokenCount = event.generatedTokenCount
            if !event.text.isEmpty {
                output += event.text
                onDelta(event.text)
            }
        }
        let generationTimeMilliseconds = Self.elapsedMilliseconds(since: startedAt)
        await recordRuntimeMetrics(
            name: "llamaCpp.generation.completed",
            metrics: LLMRuntimeMetrics(
                timeToFirstTokenMilliseconds: timeToFirstTokenMilliseconds,
                generationTimeMilliseconds: generationTimeMilliseconds,
                tokensPerSecond: Self.tokensPerSecond(
                    generatedTokenCount: generatedTokenCount,
                    elapsedMilliseconds: generationTimeMilliseconds
                ),
                memoryAfterGenerationBytes: Self.availableProcessMemoryBytes()
            )
        )
        return output
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

    private static func tokensPerSecond(generatedTokenCount: Int, elapsedMilliseconds: Int) -> Double? {
        guard generatedTokenCount > 0, elapsedMilliseconds > 0 else {
            return nil
        }
        return Double(generatedTokenCount) / (Double(elapsedMilliseconds) / 1_000)
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
        return .executionFailed(String(describing: error))
    }
}

public enum LLMBackendLlamaCppNamespace {}
