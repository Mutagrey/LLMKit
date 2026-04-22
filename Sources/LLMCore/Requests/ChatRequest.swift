import Foundation

public struct ChatRequest: Hashable, Codable, Sendable {
    public let messages: [ChatMessage]
    public let requirements: ExecutionRequirements
    public let sessionID: SessionID?

    public init(messages: [ChatMessage], requirements: ExecutionRequirements = ExecutionRequirements(), sessionID: SessionID? = nil) {
        self.messages = messages
        self.requirements = requirements
        self.sessionID = sessionID
    }
}
