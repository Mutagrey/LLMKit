import Foundation
import LLMCore
import LLMModelLifecycle
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

actor MLXLocalRuntime {
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
