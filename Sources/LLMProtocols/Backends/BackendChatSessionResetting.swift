import LLMCore

public protocol BackendChatSessionResetting: Sendable {
    func resetChatSession(modelID: ModelID, sessionID: SessionID) async
    func resetChatSessions(sessionID: SessionID) async
}
