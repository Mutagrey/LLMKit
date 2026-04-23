import Foundation

public struct ChatRequest: Hashable, Codable, Sendable {
    public let messages: [ChatMessage]
    public let requirements: ExecutionRequirements
    public let sessionID: SessionID?
    public let tools: [ToolDefinition]

    public init(
        messages: [ChatMessage],
        requirements: ExecutionRequirements = ExecutionRequirements(),
        sessionID: SessionID? = nil,
        tools: [ToolDefinition] = []
    ) {
        self.messages = messages
        self.requirements = requirements
        self.sessionID = sessionID
        self.tools = tools
    }

    public init(
        messages: [ChatMessage],
        requirements: ExecutionRequirements = ExecutionRequirements(),
        sessionID: SessionID? = nil
    ) {
        self.init(
            messages: messages,
            requirements: requirements,
            sessionID: sessionID,
            tools: []
        )
    }
}
