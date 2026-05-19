import Foundation
import LLMCore
import LLMModelLifecycle

protocol LlamaCppRuntime: Sendable {
    func nativeRuntimeAvailable() async -> Bool
    func runtimeReport() async -> LlamaCppRuntimeReport
    func hasLocalFiles(for descriptor: ModelDescriptor) async -> Bool
    func loadModel(_ descriptor: ModelDescriptor) async throws
    func unload(modelID: ModelID) async
    func unloadAll() async
    func resetChatSession(modelID: ModelID, sessionID: SessionID) async
    func resetChatSessions(sessionID: SessionID) async
    func stream(prompt: String, model descriptor: ModelDescriptor, maxTokens: Int?) async throws -> AsyncThrowingStream<String, Error>
}

actor LlamaCppLocalRuntime: LlamaCppRuntime {
    private let resolver: ModelArtifactLocationResolver
    private let configuration: LlamaCppRuntimeConfiguration
    private var contexts: [ModelID: LlamaCppNativeContext] = [:]

    init(modelRootDirectory: URL, configuration: LlamaCppRuntimeConfiguration) {
        self.resolver = ModelArtifactLocationResolver(rootDirectory: modelRootDirectory)
        self.configuration = configuration
    }

    func nativeRuntimeAvailable() async -> Bool {
        LlamaCppNativeContext.isAvailable
    }

    func runtimeReport() async -> LlamaCppRuntimeReport {
        LlamaCppNativeContext.runtimeReport(configuration: configuration)
    }

    func hasLocalFiles(for descriptor: ModelDescriptor) -> Bool {
        guard let ggufArtifacts = ggufArtifacts(for: descriptor), !ggufArtifacts.isEmpty else {
            return false
        }

        return ggufArtifacts.allSatisfy { artifact in
            guard let url = try? resolver.artifactURL(modelID: descriptor.id, artifact: artifact) else {
                return false
            }
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    func loadModel(_ descriptor: ModelDescriptor) async throws {
        guard hasLocalFiles(for: descriptor) else {
            throw LLMError.modelNotInstalled(descriptor.id)
        }
        guard LlamaCppNativeContext.isAvailable else {
            throw LLMError.unavailable
        }

        if contexts[descriptor.id] != nil {
            return
        }
        unloadModelsIfNeeded(beforeLoading: descriptor.id)
        contexts[descriptor.id] = try LlamaCppNativeContext.create(
            path: try ggufURL(for: descriptor).path,
            configuration: configuration
        )
    }

    func unload(modelID: ModelID) async {
        contexts[modelID] = nil
    }

    func unloadAll() async {
        contexts.removeAll()
    }

    func resetChatSession(modelID: ModelID, sessionID: SessionID) async {}

    func resetChatSessions(sessionID: SessionID) async {}

    func stream(
        prompt: String,
        model descriptor: ModelDescriptor,
        maxTokens: Int?
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await loadModel(descriptor)
        guard let context = contexts[descriptor.id] else {
            throw LLMError.unavailable
        }
        return await context.stream(prompt: prompt, maxTokens: maxTokens)
    }

    private func unloadModelsIfNeeded(beforeLoading modelID: ModelID) {
        contexts[modelID] = nil
        while contexts.count >= configuration.maxLoadedModels, let firstModelID = contexts.keys.first {
            contexts[firstModelID] = nil
        }
    }

    private func ggufArtifacts(for descriptor: ModelDescriptor) -> [ModelArtifact]? {
        descriptor.source?.artifacts.filter { $0.relativePath.lowercased().hasSuffix(".gguf") }
    }

    private func ggufURL(for descriptor: ModelDescriptor) throws -> URL {
        guard let artifact = ggufArtifacts(for: descriptor)?.first else {
            throw LLMError.executionFailed("No GGUF artifact declared for \(descriptor.id.rawValue).")
        }
        return try resolver.artifactURL(modelID: descriptor.id, artifact: artifact)
    }
}
