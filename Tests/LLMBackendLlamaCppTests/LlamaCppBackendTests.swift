import Foundation
@testable import LLMBackendLlamaCpp
import LLMCore
import LLMModelLifecycle
import LLMProtocols
import Testing

@Test func llamaCppSupportMatrixAcceptsLlamaQwenAndGemmaGGUFTextDescriptors() {
    let matrix = LlamaCppModelSupportMatrix()

    #expect(matrix.supports(.llama))
    #expect(matrix.supports(.qwen))
    #expect(matrix.supports(.gemma))
    #expect(matrix.supports(ggufDescriptor()))
    #expect(matrix.supports(ggufDescriptor(family: .qwen)))
    #expect(matrix.supports(ggufDescriptor(family: .gemma)))
    #expect(!matrix.supports(ggufDescriptor(capabilities: [.chat, .completion, .structuredOutput])))
    #expect(!matrix.supports(ggufDescriptor(artifactPath: "model.safetensors", quantization: Quantization(format: "MLX 4-bit", bits: 4))))
    #expect(!matrix.supports(ggufDescriptor(artifactPath: "model.safetensors")))
}

@Test func llamaCppBackendAvailabilityRequiresConfiguredRuntimeAndLocalGGUF() async throws {
    let descriptor = ggufDescriptor()

    let unavailable = await LlamaCppBackend().availability(for: descriptor)
    #expect(unavailable.status == .unavailable(reason: "llama.cpp native runtime is not configured."))

    let missingRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitLlamaCppMissing-\(UUID().uuidString)", isDirectory: true)
    let requiresInstall = await LlamaCppBackend(runtimeAvailable: true, modelRootDirectory: missingRoot).availability(for: descriptor)
    #expect(requiresInstall.status == .requiresInstall)
}

@Test func llamaCppBackendReportsAvailableWhenGGUFArtifactExists() async throws {
    let descriptor = ggufDescriptor(id: "llama/test")
    let availability = await LlamaCppBackend(runtime: FakeLlamaCppRuntime(hasFiles: true)).availability(for: descriptor)

    #expect(availability.status == .available)
}

@Test func llamaCppBackendExposesRuntimeReportWhenRuntimeIsConfigured() async throws {
    let report = LlamaCppRuntimeReport(
        supportsMMap: true,
        usesMMap: true,
        supportsGPUOffload: true,
        requestedGPULayerCount: 32,
        effectiveGPULayerCount: 32,
        supportsQuantizedKVCache: false,
        requestedKVCachePolicy: .runtimeDefault,
        effectiveKVCachePolicy: .runtimeDefault,
        kvCacheFallbackReason: nil,
        metalExecutionVerified: false
    )
    let backend = LlamaCppBackend(runtime: FakeLlamaCppRuntime(hasFiles: true, report: report))

    let resolved = await backend.runtimeReport()

    #expect(resolved == report)
}

@Test func llamaCppBackendReportsAvailableForInstalledGGUFWhenFrameworkIsLinked() async throws {
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitLlamaCppTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ggufDescriptor(id: "llama/installed")
    let artifact = try #require(descriptor.source?.artifacts.first)
    let artifactURL = try ModelArtifactLocationResolver(rootDirectory: rootDirectory)
        .artifactURL(modelID: descriptor.id, artifact: artifact)
    try FileManager.default.createDirectory(at: artifactURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("gguf".utf8).write(to: artifactURL)

    let availability = await LlamaCppBackend(
        runtimeAvailable: true,
        modelRootDirectory: rootDirectory
    ).availability(for: descriptor)

    #expect(availability.status == .available)
}

@Test func llamaCppBackendRejectsWrongBackendAndNonGGUFDescriptors() async {
    let wrongBackend = ggufDescriptor(backend: .mlx)
    let nonGGUF = ggufDescriptor(artifactPath: "model.safetensors", quantization: Quantization(format: "MLX 4-bit", bits: 4))
    let backend = LlamaCppBackend(runtimeAvailable: true)

    #expect(await backend.availability(for: wrongBackend).status == .unsupported)
    #expect(await backend.availability(for: nonGGUF).status == .unavailable(reason: "llama.cpp v1 supports Llama, Qwen, and Gemma text GGUF models only."))
}

@Test func llamaCppBackendStreamsUnavailableWhenNativeBridgeIsMissing() async throws {
    let descriptor = ggufDescriptor()
    let backend = LlamaCppBackend(runtime: FakeLlamaCppRuntime(hasFiles: true, streamError: LLMError.unavailable))

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: descriptor)) {}
        Issue.record("Expected llama.cpp generation to report unavailable without the native bridge.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}

@Test func llamaCppBackendRecordsLoadAndGenerationRuntimeMetricsWithoutPromptContent() async throws {
    let descriptor = ggufDescriptor()
    let sink = TestMetricsSink()
    let backend = LlamaCppBackend(
        runtime: FakeLlamaCppRuntime(hasFiles: true, streamDeltas: ["assistant private output"]),
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

    #expect(events.map(\.name) == ["llamaCpp.model_load.completed", "llamaCpp.generation.completed"])
    #expect(!metadataText.contains("private prompt"))
    #expect(!metadataText.contains("assistant private output"))
    #expect(events.allSatisfy { event in
        event.metadata.values.allSatisfy { Int($0) != nil || Double($0) != nil }
    })
}

@Test func llamaCppBackendRecordsTokensPerSecondOnlyFromGeneratedTokenCount() async throws {
    let descriptor = ggufDescriptor()
    let sink = TestMetricsSink()
    let backend = LlamaCppBackend(
        runtime: FakeLlamaCppRuntime(
            hasFiles: true,
            streamEvents: [
                LlamaCppGeneratedText(text: "a", generatedTokenCount: 1),
                LlamaCppGeneratedText(text: "b", generatedTokenCount: 2)
            ],
            streamDelayNanoseconds: 2_000_000
        ),
        metricsSink: sink
    )

    for try await _ in backend.generate(BackendGenerationRequest(
        request: GenerationRequest(prompt: "private prompt"),
        model: descriptor
    )) {}

    let generationEvent = try #require(await sink.snapshot().last)

    #expect(generationEvent.metadata["runtime.tokens_per_second"] != nil)
    #expect(generationEvent.metadata.keys.contains("runtime.tokens_per_second"))
}

@Test func llamaCppPromptFormatterUsesLlamaChatHeaders() throws {
    let prompt = try LlamaCppPromptFormatter().prompt(from: [
        ChatMessage(role: .system, content: MessageContent(text: "system")),
        ChatMessage(role: .user, content: MessageContent(text: "hello"))
    ])

    #expect(prompt.contains("<|start_header_id|>system<|end_header_id|>"))
    #expect(prompt.contains("<|start_header_id|>user<|end_header_id|>"))
    #expect(prompt.hasSuffix("<|start_header_id|>assistant<|end_header_id|>\n\n"))
}

@Test func llamaCppPromptFormatterUsesQwenChatTemplate() throws {
    let prompt = try LlamaCppPromptFormatter().prompt(from: [
        ChatMessage(role: .system, content: MessageContent(text: "system")),
        ChatMessage(role: .user, content: MessageContent(text: "hello"))
    ], model: ggufDescriptor(id: "qwen", family: .qwen))

    #expect(prompt.contains("<|im_start|>system\nsystem<|im_end|>"))
    #expect(prompt.contains("<|im_start|>user\nhello<|im_end|>"))
    #expect(prompt.hasSuffix("<|im_start|>assistant\n"))
}

@Test func llamaCppPromptFormatterUsesGemma3Turns() throws {
    let prompt = try LlamaCppPromptFormatter().prompt(from: [
        ChatMessage(role: .system, content: MessageContent(text: "system")),
        ChatMessage(role: .user, content: MessageContent(text: "hello"))
    ], model: ggufDescriptor(id: "gemma-3", family: .gemma))

    #expect(prompt.contains("<start_of_turn>user\nsystem\n\nhello<end_of_turn>"))
    #expect(prompt.hasSuffix("<start_of_turn>model\n"))
}

@Test func llamaCppPromptFormatterUsesGemma4Turns() throws {
    let prompt = try LlamaCppPromptFormatter().prompt(from: [
        ChatMessage(role: .system, content: MessageContent(text: "system")),
        ChatMessage(role: .user, content: MessageContent(text: "hello"))
    ], model: ggufDescriptor(id: "bartowski.google_gemma-4-E2B-it-GGUF.Q4_K_M", family: .gemma))

    #expect(prompt.hasPrefix("<bos><|turn>system\nsystem<turn|>"))
    #expect(prompt.contains("<|turn>user\nhello<turn|>"))
    #expect(prompt.hasSuffix("<|turn>model\n"))
}

@Test func llamaCppRuntimeConfigurationResolvesMMapOnlyWhenSupported() {
    let enabled = LlamaCppRuntimeConfiguration(useMMap: true)
    let disabled = LlamaCppRuntimeConfiguration(useMMap: false)

    #expect(enabled.resolvedUseMMap(isSupported: true))
    #expect(!enabled.resolvedUseMMap(isSupported: false))
    #expect(!disabled.resolvedUseMMap(isSupported: true))
}

@Test func llamaCppRuntimeConfigurationDoesNotUseGPULayersOnSimulator() {
    let configuration = LlamaCppRuntimeConfiguration(useMetal: true, gpuLayerCount: 32)

    #expect(configuration.resolvedGPULayerCount(isSimulator: true) == 0)
    #expect(configuration.resolvedGPULayerCount(isSimulator: false) == 32)
    #expect(LlamaCppRuntimeConfiguration(useMetal: false, gpuLayerCount: 32).resolvedGPULayerCount(isSimulator: false) == 0)
}

@Test func llamaCppRuntimeConfigurationDefaultsAreIPhoneConservative() {
    let configuration = LlamaCppRuntimeConfiguration.default

    #expect(configuration.contextSize == 8192)
    #expect(configuration.batchSize == 256)
    #expect(configuration.maxLoadedModels == 1)
    #expect(configuration.useMMap)
    #expect(configuration.kvCachePolicy == .runtimeDefault)
}

@Test func llamaCppBackendAppliesUpdatedRuntimeConfiguration() async {
    let runtime = FakeLlamaCppRuntime(hasFiles: true)
    let backend = LlamaCppBackend(runtime: runtime)
    let configuration = LlamaCppRuntimeConfiguration(contextSize: 16_384, batchSize: 512)

    await backend.updateConfiguration(configuration)

    #expect(await runtime.configurationUpdates() == [configuration])
}

@Test func llamaCppRuntimeReportDoesNotClaimUnsupportedMMapOrGPUOffload() {
    let configuration = LlamaCppRuntimeConfiguration(useMMap: true, useMetal: true, gpuLayerCount: 64)

    let report = LlamaCppRuntimeReport.resolved(
        configuration: configuration,
        supportsMMap: false,
        supportsGPUOffload: false,
        isSimulator: false
    )

    #expect(!report.usesMMap)
    #expect(report.requestedGPULayerCount == 64)
    #expect(report.effectiveGPULayerCount == 0)
    #expect(!report.metalExecutionVerified)
}

@Test func llamaCppRuntimeReportFallsBackFromUnsupportedExperimentalKVCachePolicy() {
    let configuration = LlamaCppRuntimeConfiguration(kvCachePolicy: .q8Experimental)

    let report = LlamaCppRuntimeReport.resolved(
        configuration: configuration,
        supportsMMap: true,
        supportsGPUOffload: true,
        supportsQuantizedKVCache: false,
        isSimulator: false
    )

    #expect(report.requestedKVCachePolicy == .q8Experimental)
    #expect(report.effectiveKVCachePolicy == .runtimeDefault)
    #expect(report.kvCacheFallbackReason != nil)
}

@Test func llamaCppRuntimeReportKeepsExperimentalKVCachePolicyWhenSupported() {
    let configuration = LlamaCppRuntimeConfiguration(kvCachePolicy: .q4Experimental)

    let report = LlamaCppRuntimeReport.resolved(
        configuration: configuration,
        supportsMMap: true,
        supportsGPUOffload: true,
        supportsQuantizedKVCache: true,
        isSimulator: false
    )

    #expect(report.requestedKVCachePolicy == .q4Experimental)
    #expect(report.effectiveKVCachePolicy == .q4Experimental)
    #expect(report.kvCacheFallbackReason == nil)
}

@Test func llamaCppRuntimeReportDisablesGPUOffloadOnSimulator() {
    let configuration = LlamaCppRuntimeConfiguration(useMetal: true, gpuLayerCount: 64)

    let report = LlamaCppRuntimeReport.resolved(
        configuration: configuration,
        supportsMMap: true,
        supportsGPUOffload: true,
        isSimulator: true
    )

    #expect(report.usesMMap)
    #expect(report.requestedGPULayerCount == 0)
    #expect(report.effectiveGPULayerCount == 0)
}

private actor FakeLlamaCppRuntime: LlamaCppRuntime {
    private let hasFiles: Bool
    private let nativeAvailable: Bool
    private let streamError: LLMError?
    private let streamEvents: [LlamaCppGeneratedText]
    private let streamDelayNanoseconds: UInt64?
    private let report: LlamaCppRuntimeReport
    private var recordedConfigurationUpdates: [LlamaCppRuntimeConfiguration] = []

    init(
        hasFiles: Bool,
        nativeAvailable: Bool = true,
        streamError: LLMError? = nil,
        streamDeltas: [String] = ["ok"],
        streamEvents: [LlamaCppGeneratedText]? = nil,
        streamDelayNanoseconds: UInt64? = nil,
        report: LlamaCppRuntimeReport = LlamaCppRuntimeReport.resolved(
            configuration: .default,
            supportsMMap: true,
            supportsGPUOffload: true,
            supportsQuantizedKVCache: false,
            isSimulator: false
        )
    ) {
        self.hasFiles = hasFiles
        self.nativeAvailable = nativeAvailable
        self.streamError = streamError
        self.streamEvents = streamEvents ?? streamDeltas.enumerated().map { index, delta in
            LlamaCppGeneratedText(text: delta, generatedTokenCount: index + 1)
        }
        self.streamDelayNanoseconds = streamDelayNanoseconds
        self.report = report
    }

    func nativeRuntimeAvailable() async -> Bool {
        nativeAvailable
    }

    func runtimeReport() async -> LlamaCppRuntimeReport {
        report
    }

    func hasLocalFiles(for descriptor: ModelDescriptor) -> Bool {
        hasFiles
    }

    func loadModel(_ descriptor: ModelDescriptor) async throws {}

    func unload(modelID: ModelID) async {}

    func unloadAll() async {}

    func updateConfiguration(_ configuration: LlamaCppRuntimeConfiguration) async {
        recordedConfigurationUpdates.append(configuration)
    }

    func resetChatSession(modelID: ModelID, sessionID: SessionID) async {}

    func resetChatSessions(sessionID: SessionID) async {}

    func stream(
        prompt: String,
        model descriptor: ModelDescriptor,
        maxTokens: Int?
    ) async throws -> AsyncThrowingStream<LlamaCppGeneratedText, Error> {
        if let streamError {
            throw streamError
        }
        let streamEvents = self.streamEvents
        let streamDelayNanoseconds = self.streamDelayNanoseconds
        return AsyncThrowingStream { continuation in
            Task {
                for event in streamEvents {
                    if let streamDelayNanoseconds {
                        try? await Task.sleep(nanoseconds: streamDelayNanoseconds)
                    }
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    func configurationUpdates() -> [LlamaCppRuntimeConfiguration] {
        recordedConfigurationUpdates
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

private func ggufDescriptor(
    id: ModelID = "llama",
    family: ModelFamily = .llama,
    backend: BackendKind = .llamaCpp,
    capabilities: Set<ModelCapability> = [.chat, .completion, .streaming, .offline],
    artifactPath: String = "model.gguf",
    quantization: Quantization? = Quantization(format: "GGUF Q4_K_M", bits: 4)
) -> ModelDescriptor {
    ModelDescriptor(
        id: id,
        displayName: "Llama GGUF",
        family: family,
        backend: backend,
        capabilities: capabilities,
        supportsStreaming: true,
        source: ModelSource(
            provider: .remoteURL,
            artifacts: [
                ModelArtifact(
                    id: artifactPath,
                    url: URL(string: "https://example.com/\(artifactPath)")!,
                    relativePath: artifactPath
                )
            ]
        ),
        quantization: quantization,
        tags: quantization?.format.contains("GGUF") == true ? ["gguf"] : []
    )
}
