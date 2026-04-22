import LLMCore

public protocol SessionService: Sendable {
    func createSession(title: String?) async -> SessionSnapshot
    func loadSession(id: SessionID) async throws -> SessionSnapshot?
    func append(_ message: ChatMessage, to sessionID: SessionID) async throws -> SessionSnapshot
}
