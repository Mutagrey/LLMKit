import Foundation
import LLMCore
import LLMModelLifecycle
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers

actor MLXLocalRuntime {
    private let resolver: ModelArtifactLocationResolver
    private var memoryPolicy: MLXMemoryPolicy
    private var containers: [ModelID: ModelContainer] = [:]
    private var chatSessions: [MLXChatSessionKey: MLXChatSessionState] = [:]

    init(modelRootDirectory: URL, memoryPolicy: MLXMemoryPolicy = .default) {
        self.resolver = ModelArtifactLocationResolver(rootDirectory: modelRootDirectory)
        self.memoryPolicy = memoryPolicy
        Self.apply(memoryPolicy)
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

        unloadContainersIfNeeded(beforeLoading: descriptor.id)

        let container = try await LLMModelFactory.shared.loadContainer(
            from: directory,
            using: TransformersTokenizerLoader()
        )
        containers[descriptor.id] = container
        return container
    }

    func unload(modelID: ModelID) {
        containers[modelID] = nil
        chatSessions = chatSessions.filter { $0.key.modelID != modelID }
        clearCacheAfterUnloadIfNeeded()
    }

    func resetChatSession(modelID: ModelID, sessionID: SessionID) {
        chatSessions[MLXChatSessionKey(modelID: modelID, sessionID: sessionID)] = nil
    }

    func resetChatSessions(sessionID: SessionID) {
        chatSessions = chatSessions.filter { $0.key.sessionID != sessionID }
    }

    func stream(
        prompt: String,
        model descriptor: ModelDescriptor,
        maxTokens: Int?
    ) async throws -> AsyncThrowingStream<String, Error> {
        let container = try await loadContainer(for: descriptor)
        let session = ChatSession(
            container,
            generateParameters: generateParameters(maxTokens: maxTokens)
        )
        return session.streamResponse(to: prompt)
    }

    func stream(
        messages: [ChatMessage],
        sessionID: SessionID?,
        model descriptor: ModelDescriptor,
        maxTokens: Int?
    ) async throws -> AsyncThrowingStream<String, Error> {
        let container = try await loadContainer(for: descriptor)
        let mapped = try MLXChatMessageMapper().prompt(from: messages)
        let generateParameters = generateParameters(maxTokens: maxTokens)

        guard let sessionID, memoryPolicy.retainChatSessions else {
            let session = ChatSession(
                container,
                history: mapped.history,
                generateParameters: generateParameters
            )
            return session.streamResponse(
                to: mapped.prompt.content,
                role: mapped.prompt.role,
                images: [],
                videos: []
            )
        }

        let key = MLXChatSessionKey(modelID: descriptor.id, sessionID: sessionID)
        let expectedCachedMessageCount = mapped.history.count
        let session: ChatSession
        if let state = chatSessions[key], state.cachedMessageCount == expectedCachedMessageCount {
            session = state.session
        } else {
            session = ChatSession(
                container,
                history: mapped.history,
                generateParameters: generateParameters
            )
            chatSessions[key] = MLXChatSessionState(
                session: session,
                cachedMessageCount: expectedCachedMessageCount
            )
        }

        return session.streamResponse(
            to: mapped.prompt.content,
            role: mapped.prompt.role,
            images: [],
            videos: []
        )
    }

    func recordChatCompletion(modelID: ModelID, sessionID: SessionID?, requestMessageCount: Int) {
        guard let sessionID, memoryPolicy.retainChatSessions else {
            return
        }
        let key = MLXChatSessionKey(modelID: modelID, sessionID: sessionID)
        chatSessions[key]?.cachedMessageCount = requestMessageCount + 1
    }

    func updateMemoryPolicy(_ memoryPolicy: MLXMemoryPolicy) {
        self.memoryPolicy = memoryPolicy
        Self.apply(memoryPolicy)
        if !memoryPolicy.retainChatSessions {
            chatSessions.removeAll()
        }
    }

    func finishGenerationCleanup() {
        guard memoryPolicy.clearCacheAfterGeneration else {
            return
        }
        Memory.clearCache()
    }

    private func unloadContainersIfNeeded(beforeLoading modelID: ModelID) {
        guard let maxLoadedModels = memoryPolicy.maxLoadedModels else {
            return
        }
        let loadedModelIDs = Array(containers.keys.filter { $0 != modelID })
        guard loadedModelIDs.count >= maxLoadedModels else {
            return
        }
        for loadedModelID in loadedModelIDs {
            containers[loadedModelID] = nil
        }
        chatSessions = chatSessions.filter { $0.key.modelID == modelID }
        clearCacheAfterUnloadIfNeeded()
    }

    private func clearCacheAfterUnloadIfNeeded() {
        guard memoryPolicy.clearCacheOnUnload else {
            return
        }
        Memory.clearCache()
    }

    private static func apply(_ memoryPolicy: MLXMemoryPolicy) {
        if let cacheLimitBytes = memoryPolicy.cacheLimitBytes {
            Memory.cacheLimit = cacheLimitBytes
        }
    }

    private func generateParameters(maxTokens: Int?) -> GenerateParameters {
        let defaults = GenerateParameters(maxTokens: maxTokens ?? 256)
        return GenerateParameters(
            maxTokens: maxTokens ?? 256,
            maxKVSize: memoryPolicy.maxKVSize ?? defaults.maxKVSize,
            kvBits: memoryPolicy.kvBits ?? defaults.kvBits,
            kvGroupSize: memoryPolicy.kvGroupSize,
            quantizedKVStart: memoryPolicy.quantizedKVStart,
            temperature: defaults.temperature,
            topP: defaults.topP,
            topK: defaults.topK,
            minP: defaults.minP,
            repetitionPenalty: defaults.repetitionPenalty,
            repetitionContextSize: defaults.repetitionContextSize,
            presencePenalty: defaults.presencePenalty,
            presenceContextSize: defaults.presenceContextSize,
            frequencyPenalty: defaults.frequencyPenalty,
            frequencyContextSize: defaults.frequencyContextSize,
            prefillStepSize: memoryPolicy.prefillStepSize ?? defaults.prefillStepSize
        )
    }
}

private struct MLXChatSessionKey: Hashable {
    let modelID: ModelID
    let sessionID: SessionID
}

private struct MLXChatSessionState {
    let session: ChatSession
    var cachedMessageCount: Int
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
