import Foundation
@testable import LLMBackendMLX
import LLMCore
import LLMModelLifecycle
import LLMProtocols
import Testing

@Test func mlxSupportMatrixIncludesInitialFamilies() {
    #expect(MLXModelSupportMatrix().supports(.qwen))
    #expect(MLXModelSupportMatrix().supports(.gemma))
    #expect(MLXModelSupportMatrix().supports(.llama))
    #expect(MLXModelSupportMatrix().supports(.mistral))
    #expect(!MLXModelSupportMatrix().supports(.custom("test")))
}

@Test func mlxBackendRequiresRuntimeBeforeLoading() async throws {
    let descriptor = ModelDescriptor(id: "mlx", displayName: "MLX", family: .qwen, backend: .mlx, capabilities: [.completion])

    let unavailable = await MLXBackend().availability(for: descriptor)
    let requiresInstall = await MLXBackend(
        runtimeAvailable: true,
        modelRootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    ).availability(for: descriptor)

    #expect(unavailable.status != .available)
    #expect(requiresInstall.status == .requiresInstall)
}

@Test func mlxDefaultMemoryPolicyPreservesRuntimeBehavior() {
    let policy = MLXMemoryPolicy.default

    #expect(policy.cacheLimitBytes == nil)
    #expect(!policy.clearCacheAfterGeneration)
    #expect(!policy.clearCacheOnUnload)
    #expect(policy.maxLoadedModels == nil)
    #expect(policy.retainChatSessions)
    #expect(policy.maxKVSize == nil)
    #expect(policy.kvBits == nil)
    #expect(policy.prefillStepSize == nil)
}

@Test func mlxStrictMemoryPolicyDisablesSessionRetentionAndCapsCache() {
    let policy = MLXMemoryPolicy.strictForMemoryConstrainedApps

    #expect(policy.cacheLimitBytes == 64 * 1024 * 1024)
    #expect(policy.clearCacheAfterGeneration)
    #expect(policy.clearCacheOnUnload)
    #expect(policy.maxLoadedModels == 1)
    #expect(!policy.retainChatSessions)
    #expect(policy.maxKVSize == 8_192)
    #expect(policy.kvBits == 4)
    #expect(policy.kvGroupSize == 64)
    #expect(policy.quantizedKVStart == 0)
    #expect(policy.prefillStepSize == 256)
}

@Test func mlxBackendRejectsUnsupportedFamilyAndWrongBackend() async throws {
    let unsupportedFamily = ModelDescriptor(id: "custom", displayName: "Custom", family: .custom("test"), backend: .mlx, capabilities: [.completion])
    let wrongBackend = ModelDescriptor(id: "coreml", displayName: "Core ML", family: .qwen, backend: .coreML, capabilities: [.completion])
    let backend = MLXBackend(runtimeAvailable: true)

    #expect(await backend.availability(for: unsupportedFamily).status == .unsupported)
    #expect(await backend.availability(for: wrongBackend).status == .unsupported)
}

@Test func mlxBackendAcceptsVLMDescriptorsForTextRuntimeAvailability() async {
    let descriptor = ModelDescriptor(
        id: "mlx-multimodal",
        displayName: "Multimodal MLX",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat, .multimodalInput]
    )

    let availability = await MLXBackend(runtimeAvailable: true).availability(for: descriptor)

    #expect(availability.status == .requiresInstall)
}

@Test func mlxBackendStreamsUnavailableWhenRuntimeIsNotConfigured() async throws {
    let descriptor = ModelDescriptor(id: "mlx", displayName: "MLX", family: .qwen, backend: .mlx, capabilities: [.completion])
    let backend = MLXBackend()

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: descriptor)) {}
        Issue.record("Expected MLX generation skeleton to be unavailable.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}

@Test func mlxBackendRecordsRuntimeMetricsWithTokensPerSecondWithoutPromptContent() async throws {
    let descriptor = ModelDescriptor(id: "mlx", displayName: "MLX", family: .qwen, backend: .mlx, capabilities: [.completion])
    let sink = TestMetricsSink()
    let backend = MLXBackend(
        runtime: FakeMLXRuntime(events: [
            .chunk("assistant private output"),
            .info(generationTimeMilliseconds: 20, tokensPerSecond: 42.5)
        ]),
        metricsSink: sink
    )

    for try await _ in backend.generate(BackendGenerationRequest(
        request: GenerationRequest(prompt: "private prompt"),
        model: descriptor
    )) {}

    let events = await sink.snapshot()
    let metadataText = events.flatMap { event in
        Array(event.metadata.keys) + Array(event.metadata.values)
    }.joined(separator: " ")
    let generationEvent = try #require(events.last)

    #expect(events.map(\.name) == ["mlx.model_load.completed", "mlx.generation.completed"])
    #expect(generationEvent.metadata["runtime.tokens_per_second"] == "42.5")
    #expect(!metadataText.contains("private prompt"))
    #expect(!metadataText.contains("assistant private output"))
}

@Test func mlxBackendReportsAvailableWhenModelDirectoryExists() async throws {
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitMLXTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen",
        displayName: "Qwen",
        family: .qwen,
        backend: .mlx,
        capabilities: [.completion]
    )
    let modelDirectory = ModelArtifactLocationResolver(rootDirectory: rootDirectory)
        .modelDirectory(for: descriptor.id)
    try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: modelDirectory.appendingPathComponent("config.json"))

    let availability = await MLXBackend(
        runtimeAvailable: true,
        modelRootDirectory: rootDirectory
    ).availability(for: descriptor)

    #expect(availability.status == .available)
}

@Test func mlxChatMessageMapperPreservesBackendNeutralRoles() throws {
    let messages = [
        ChatMessage(role: .system, content: MessageContent(text: "system")),
        ChatMessage(role: .developer, content: MessageContent(text: "developer")),
        ChatMessage(role: .user, content: MessageContent(text: "user")),
        ChatMessage(role: .assistant, content: MessageContent(text: "assistant")),
        ChatMessage(role: .tool, content: MessageContent(text: "tool"))
    ]

    let mapped = MLXChatMessageMapper().map(messages)

    #expect(mapped.map(\.role.rawValue) == ["system", "system", "user", "assistant", "tool"])
    #expect(mapped.map(\.content) == ["system", "Developer: developer", "user", "assistant", "tool"])
}

@Test func mlxChatMessageMapperSplitsHistoryFromPrompt() throws {
    let prompt = try MLXChatMessageMapper().prompt(from: [
        ChatMessage(role: .system, content: MessageContent(text: "system")),
        ChatMessage(role: .user, content: MessageContent(text: "latest"))
    ])

    #expect(prompt.history.count == 1)
    #expect(prompt.history.first?.role.rawValue == "system")
    #expect(prompt.prompt.role.rawValue == "user")
    #expect(prompt.prompt.content == "latest")
}

private actor FakeMLXRuntime: MLXRuntime {
    private let events: [MLXRuntimeGenerationEvent]

    init(events: [MLXRuntimeGenerationEvent] = [.chunk("ok")]) {
        self.events = events
    }

    func hasLocalFiles(for descriptor: ModelDescriptor) -> Bool {
        true
    }

    func loadModel(_ descriptor: ModelDescriptor) async throws {}

    func unload(modelID: ModelID) async {}

    func unloadAll() async {}

    func updateMemoryPolicy(_ memoryPolicy: MLXMemoryPolicy) async {}

    func resetChatSession(modelID: ModelID, sessionID: SessionID) async {}

    func resetChatSessions(sessionID: SessionID) async {}

    func stream(
        prompt: String,
        model descriptor: ModelDescriptor,
        maxTokens: Int?
    ) async throws -> AsyncThrowingStream<MLXRuntimeGenerationEvent, Error> {
        stream()
    }

    func stream(
        messages: [ChatMessage],
        sessionID: SessionID?,
        model descriptor: ModelDescriptor,
        maxTokens: Int?
    ) async throws -> AsyncThrowingStream<MLXRuntimeGenerationEvent, Error> {
        stream()
    }

    func recordChatCompletion(modelID: ModelID, sessionID: SessionID?, requestMessageCount: Int) async {}

    func finishGenerationCleanup() async {}

    private func stream() -> AsyncThrowingStream<MLXRuntimeGenerationEvent, Error> {
        let events = self.events
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

private actor TestMetricsSink: MetricsSink {
    private var events: [TelemetryEvent] = []

    func record(_ event: TelemetryEvent) async {
        events.append(event)
    }

    func snapshot() -> [TelemetryEvent] {
        events
    }
}
