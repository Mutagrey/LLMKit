import Foundation
import LLMCore
import LLMObservability
import LLMProtocols

public struct FoundationModelsBackend: ModelBackend {
    public let backendKind: BackendKind = .foundationModels
    private let configuredAvailability: FoundationModelsRuntimeAvailability?
    private let runtime: any FoundationModelsRuntime
    private let metricsSink: (any MetricsSink)?

    public init(
        runtimeAvailability: FoundationModelsRuntimeAvailability? = nil,
        metricsSink: (any MetricsSink)? = nil
    ) {
        self.configuredAvailability = runtimeAvailability
        self.runtime = FoundationModelsNativeRuntime()
        self.metricsSink = metricsSink
    }

    init(
        runtimeAvailability: FoundationModelsRuntimeAvailability? = nil,
        runtime: any FoundationModelsRuntime,
        metricsSink: (any MetricsSink)? = nil
    ) {
        self.configuredAvailability = runtimeAvailability
        self.runtime = runtime
        self.metricsSink = metricsSink
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
            let reason = runtimeAvailability.reason ?? "Foundation Models runtime is unavailable."
            return BackendAvailability(
                status: .unavailable(reason: reason),
                reason: reason,
                failure: runtimeAvailability.failure ?? .unavailable
            )
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
        let availability = await availability(for: descriptor)
        guard availability.status == .available else {
            throw availability.failure ?? .unavailable
        }
        return LoadedModelHandle(id: descriptor.id, backend: descriptor.backend)
    }

    public func unloadModel(_ handle: LoadedModelHandle) async {}

    public func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started(request.model))
            let task = Task {
                do {
                    try await ensureAvailable(request.model)
                    let startedAt = Date()
                    var accumulator = StreamedTextAccumulator()
                    var timeToFirstTokenMilliseconds: Int?
                    for try await delta in runtime.generate(request) {
                        guard !delta.isEmpty else {
                            continue
                        }
                        if timeToFirstTokenMilliseconds == nil {
                            timeToFirstTokenMilliseconds = Self.elapsedMilliseconds(since: startedAt)
                        }
                        accumulator.append(delta)
                        continuation.yield(.delta(delta))
                    }
                    await recordRuntimeMetrics(
                        name: "foundationModels.generation.completed",
                        metrics: LLMRuntimeMetrics(
                            timeToFirstTokenMilliseconds: timeToFirstTokenMilliseconds,
                            generationTimeMilliseconds: Self.elapsedMilliseconds(since: startedAt)
                        )
                    )
                    continuation.yield(.completed(GenerationResult(text: accumulator.text, model: request.model)))
                    continuation.finish()
                } catch let error as LLMError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMError.executionFailed(error.localizedDescription))
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started(request.model))
            let task = Task {
                do {
                    try await ensureAvailable(request.model)
                    let startedAt = Date()
                    var accumulator = StreamedTextAccumulator()
                    var timeToFirstTokenMilliseconds: Int?
                    for try await delta in runtime.chat(request) {
                        guard !delta.isEmpty else {
                            continue
                        }
                        if timeToFirstTokenMilliseconds == nil {
                            timeToFirstTokenMilliseconds = Self.elapsedMilliseconds(since: startedAt)
                        }
                        accumulator.append(delta)
                        continuation.yield(.delta(delta))
                    }
                    await recordRuntimeMetrics(
                        name: "foundationModels.chat.completed",
                        metrics: LLMRuntimeMetrics(
                            timeToFirstTokenMilliseconds: timeToFirstTokenMilliseconds,
                            generationTimeMilliseconds: Self.elapsedMilliseconds(since: startedAt)
                        )
                    )
                    let message = ChatMessage(role: .assistant, content: MessageContent(text: accumulator.text))
                    continuation.yield(.completed(ChatResult(message: message, model: request.model)))
                    continuation.finish()
                } catch let error as LLMError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMError.executionFailed(error.localizedDescription))
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private var supportedCapabilities: Set<ModelCapability> {
        [.chat, .completion, .streaming, .structuredOutput, .summarization, .extraction, .classification, .offline, .lowLatency]
    }

    private func supportsAnyFoundationModelCapability(_ capabilities: Set<ModelCapability>) -> Bool {
        !capabilities.isDisjoint(with: supportedCapabilities)
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

    private func ensureAvailable(_ descriptor: ModelDescriptor) async throws {
        let availability = await availability(for: descriptor)
        guard availability.status == .available else {
            throw availability.failure ?? .unavailable
        }
    }
}
