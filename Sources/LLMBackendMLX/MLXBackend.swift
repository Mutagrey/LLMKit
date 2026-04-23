import Foundation
import LLMCore
import LLMModelLifecycle
import LLMObservability
import LLMProtocols
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

public struct MLXBackend: ModelBackend {
    public let backendKind: BackendKind = .mlx
    private let runtime: MLXLocalRuntime?
    private let supportMatrix: MLXModelSupportMatrix

    public init(
        runtimeAvailable: Bool = false,
        modelRootDirectory: URL? = ModelArtifactLocationResolver.defaultRootDirectory(),
        supportMatrix: MLXModelSupportMatrix = MLXModelSupportMatrix()
    ) {
        if runtimeAvailable, let modelRootDirectory {
            self.runtime = MLXLocalRuntime(modelRootDirectory: modelRootDirectory)
        } else {
            self.runtime = nil
        }
        self.supportMatrix = supportMatrix
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        guard supportMatrix.supports(descriptor.family) else {
            return .unsupported
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

    public func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let runtime else {
                        throw LLMError.unavailable
                    }
                    continuation.yield(.started(request.model))
                    var output = ""
                    let stream = try await runtime.stream(
                        prompt: request.request.prompt,
                        model: request.model,
                        maxTokens: request.request.requirements.budget?.maxOutputTokens
                    )
                    for try await delta in stream {
                        output += delta
                        continuation.yield(.delta(delta))
                    }
                    continuation.yield(.completed(GenerationResult(text: output, model: request.model)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapRuntimeError(error))
                }
            }
        }
    }

    public func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let runtime else {
                        throw LLMError.unavailable
                    }
                    let prompt = request.request.messages.map { message in
                        "\(message.role.rawValue): \(message.content.text)"
                    }.joined(separator: "\n")
                    continuation.yield(.started(request.model))
                    var output = ""
                    let stream = try await runtime.stream(
                        prompt: prompt,
                        model: request.model,
                        maxTokens: request.request.requirements.budget?.maxOutputTokens
                    )
                    for try await delta in stream {
                        output += delta
                        continuation.yield(.delta(delta))
                    }
                    let message = ChatMessage(role: .assistant, content: MessageContent(text: output))
                    continuation.yield(.completed(ChatResult(message: message, model: request.model)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapRuntimeError(error))
                }
            }
        }
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

public struct MLXModelSupportMatrix: Sendable {
    public init() {}

    public func supports(_ family: ModelFamily) -> Bool {
        switch family {
        case .qwen, .gemma:
            true
        default:
            false
        }
    }
}

private actor MLXLocalRuntime {
    private let resolver: ModelArtifactLocationResolver
    private var containers: [ModelID: ModelContainer] = [:]

    init(modelRootDirectory: URL) {
        self.resolver = ModelArtifactLocationResolver(rootDirectory: modelRootDirectory)
    }

    func hasLocalFiles(for descriptor: ModelDescriptor) -> Bool {
        if let artifacts = descriptor.source?.artifacts, !artifacts.isEmpty {
            return artifacts.allSatisfy { artifact in
                guard let url = try? resolver.artifactURL(modelID: descriptor.id, artifact: artifact) else {
                    return false
                }
                return FileManager.default.fileExists(atPath: url.path)
            }
        }

        let directory = resolver.modelDirectory(for: descriptor.id)
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent("config.json").path)
    }

    @discardableResult
    func loadContainer(for descriptor: ModelDescriptor) async throws -> ModelContainer {
        if let container = containers[descriptor.id] {
            return container
        }

        let directory = resolver.modelDirectory(for: descriptor.id)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw LLMError.modelNotInstalled(descriptor.id)
        }

        let container = try await LLMModelFactory.shared.loadContainer(
            from: directory,
            using: #huggingFaceTokenizerLoader()
        )
        containers[descriptor.id] = container
        return container
    }

    func unload(modelID: ModelID) {
        containers[modelID] = nil
    }

    func stream(
        prompt: String,
        model descriptor: ModelDescriptor,
        maxTokens: Int?
    ) async throws -> AsyncThrowingStream<String, Error> {
        let container = try await loadContainer(for: descriptor)
        let session = ChatSession(
            container,
            generateParameters: GenerateParameters(maxTokens: maxTokens ?? 256)
        )
        return session.streamResponse(to: prompt)
    }
}

public enum LLMBackendMLXNamespace {}
