import Foundation
import LLMCore
import LLMModelLifecycle
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
            using: TransformersTokenizerLoader()
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

private struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return TransformersTokenizerBridge(tokenizer)
    }
}

private struct TransformersTokenizerBridge: MLXLMCommon.Tokenizer {
    private let tokenizer: any Tokenizers.Tokenizer

    init(_ tokenizer: any Tokenizers.Tokenizer) {
        self.tokenizer = tokenizer
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        tokenizer.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        tokenizer.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        tokenizer.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        tokenizer.convertIdToToken(id)
    }

    var bosToken: String? {
        tokenizer.bosToken
    }

    var eosToken: String? {
        tokenizer.eosToken
    }

    var unknownToken: String? {
        tokenizer.unknownToken
    }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try tokenizer.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}
