import LLMCore

public protocol SessionStore: Sendable {
    func listSessions() async throws -> [SessionOverview]
    func loadSession(id: SessionID) async throws -> SessionSnapshot?
    func saveSession(_ snapshot: SessionSnapshot) async throws
    func deleteSession(id: SessionID) async throws
}
