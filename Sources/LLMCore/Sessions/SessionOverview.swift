import Foundation

public struct SessionOverview: Hashable, Codable, Sendable, Identifiable {
    public let id: SessionID
    public let title: String?
    public let kind: SessionKind
    public let createdAt: Date
    public let updatedAt: Date
    public let messageCount: Int
    public let lastMessagePreview: String?
    public let summary: SessionSummary?
    public let executionRequirements: ExecutionRequirements?
    public let automationState: AutomatedConversationRunState?

    public init(
        id: SessionID,
        title: String? = nil,
        kind: SessionKind,
        createdAt: Date,
        updatedAt: Date,
        messageCount: Int,
        lastMessagePreview: String? = nil,
        summary: SessionSummary? = nil,
        executionRequirements: ExecutionRequirements? = nil,
        automationState: AutomatedConversationRunState? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.lastMessagePreview = lastMessagePreview
        self.summary = summary
        self.executionRequirements = executionRequirements
        self.automationState = automationState
    }
}
