import Foundation
@testable import LLMBackendLlamaCpp
import LLMCore
import LLMModelLifecycle
import LLMProtocols
import Testing

@Test func llamaCppSupportMatrixAcceptsOnlyLlamaGGUFTextDescriptors() {
    let matrix = LlamaCppModelSupportMatrix()

    #expect(matrix.supports(.llama))
    #expect(!matrix.supports(.qwen))
    #expect(matrix.supports(ggufDescriptor()))
    #expect(!matrix.supports(ggufDescriptor(family: .qwen)))
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
    #expect(await backend.availability(for: nonGGUF).status == .unavailable(reason: "llama.cpp v1 supports Llama text GGUF models only."))
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

@Test func llamaCppPromptFormatterUsesLlamaChatHeaders() throws {
    let prompt = try LlamaCppPromptFormatter().prompt(from: [
        ChatMessage(role: .system, content: MessageContent(text: "system")),
        ChatMessage(role: .user, content: MessageContent(text: "hello"))
    ])

    #expect(prompt.contains("<|start_header_id|>system<|end_header_id|>"))
    #expect(prompt.contains("<|start_header_id|>user<|end_header_id|>"))
    #expect(prompt.hasSuffix("<|start_header_id|>assistant<|end_header_id|>\n\n"))
}

private actor FakeLlamaCppRuntime: LlamaCppRuntime {
    private let hasFiles: Bool
    private let nativeAvailable: Bool
    private let streamError: LLMError?

    init(hasFiles: Bool, nativeAvailable: Bool = true, streamError: LLMError? = nil) {
        self.hasFiles = hasFiles
        self.nativeAvailable = nativeAvailable
        self.streamError = streamError
    }

    func nativeRuntimeAvailable() async -> Bool {
        nativeAvailable
    }

    func hasLocalFiles(for descriptor: ModelDescriptor) -> Bool {
        hasFiles
    }

    func loadModel(_ descriptor: ModelDescriptor) async throws {}

    func unload(modelID: ModelID) async {}

    func resetChatSession(modelID: ModelID, sessionID: SessionID) async {}

    func resetChatSessions(sessionID: SessionID) async {}

    func stream(
        prompt: String,
        model descriptor: ModelDescriptor,
        maxTokens: Int?
    ) async throws -> AsyncThrowingStream<String, Error> {
        if let streamError {
            throw streamError
        }
        return AsyncThrowingStream { continuation in
            continuation.yield("ok")
            continuation.finish()
        }
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
