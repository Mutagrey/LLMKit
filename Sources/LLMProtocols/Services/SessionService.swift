import LLMCore

public protocol SessionService: Sendable {
    func listSessions() async throws -> [SessionOverview]
    func createSession(
        title: String?,
        kind: SessionKind,
        executionRequirements: ExecutionRequirements?,
        automationDefinition: AutomatedConversationDefinition?,
        automationState: AutomatedConversationRunState?
    ) async throws -> SessionSnapshot
    func loadSession(id: SessionID) async throws -> SessionSnapshot?
    func saveSession(_ snapshot: SessionSnapshot) async throws
    func append(_ message: ChatMessage, to sessionID: SessionID) async throws -> SessionSnapshot
    func deleteSession(id: SessionID) async throws
}

public extension SessionService {
    func createSession(title: String? = nil) async -> SessionSnapshot {
        if let snapshot = try? await createSession(
            title: title,
            kind: .manualChat,
            executionRequirements: nil,
            automationDefinition: nil,
            automationState: nil
        ) {
            return snapshot
        }
        let sessionID = SessionID.generated()
        return SessionSnapshot(
            id: sessionID,
            descriptor: SessionDescriptor(id: sessionID, title: title)
        )
    }
}
