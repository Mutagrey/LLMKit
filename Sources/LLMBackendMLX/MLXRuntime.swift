import LLMCore

protocol MLXRuntime: Sendable {
    func hasLocalFiles(for descriptor: ModelDescriptor) async -> Bool
    func loadModel(_ descriptor: ModelDescriptor) async throws
    func unload(modelID: ModelID) async
    func unloadAll() async
    func updateMemoryPolicy(_ memoryPolicy: MLXMemoryPolicy) async
    func resetChatSession(modelID: ModelID, sessionID: SessionID) async
    func resetChatSessions(sessionID: SessionID) async
    func stream(prompt: String, model descriptor: ModelDescriptor, maxTokens: Int?) async throws -> AsyncThrowingStream<MLXRuntimeGenerationEvent, Error>
    func stream(messages: [ChatMessage], sessionID: SessionID?, model descriptor: ModelDescriptor, maxTokens: Int?) async throws -> AsyncThrowingStream<MLXRuntimeGenerationEvent, Error>
    func recordChatCompletion(modelID: ModelID, sessionID: SessionID?, requestMessageCount: Int) async
    func finishGenerationCleanup() async
}
