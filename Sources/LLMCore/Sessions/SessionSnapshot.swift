import Foundation

public struct SessionDescriptor: Hashable, Codable, Sendable, Identifiable {
    public let id: SessionID
    public let title: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: SessionID, title: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SessionSummary: Hashable, Codable, Sendable {
    public let text: String
    public let sourceMessageCount: Int

    public init(text: String, sourceMessageCount: Int) {
        self.text = text
        self.sourceMessageCount = sourceMessageCount
    }
}

public struct SessionSnapshot: Hashable, Codable, Sendable, Identifiable {
    public let id: SessionID
    public let descriptor: SessionDescriptor
    public let kind: SessionKind
    public let messages: [ChatMessage]
    public let summary: SessionSummary?
    public let executionRequirements: ExecutionRequirements?
    public let automationDefinition: AutomatedConversationDefinition?
    public let automationState: AutomatedConversationRunState?

    public init(
        id: SessionID,
        descriptor: SessionDescriptor,
        kind: SessionKind = .manualChat,
        messages: [ChatMessage] = [],
        summary: SessionSummary? = nil,
        executionRequirements: ExecutionRequirements? = nil,
        automationDefinition: AutomatedConversationDefinition? = nil,
        automationState: AutomatedConversationRunState? = nil
    ) {
        self.id = id
        self.descriptor = descriptor
        self.kind = kind
        self.messages = messages
        self.summary = summary
        self.executionRequirements = executionRequirements
        self.automationDefinition = automationDefinition
        self.automationState = automationState
    }

    public var overview: SessionOverview {
        SessionOverview(
            id: id,
            title: descriptor.title,
            kind: kind,
            createdAt: descriptor.createdAt,
            updatedAt: descriptor.updatedAt,
            messageCount: messages.count,
            lastMessagePreview: messages.last?.content.text,
            summary: summary,
            executionRequirements: executionRequirements,
            automationState: automationState
        )
    }
}

public enum SessionState: Hashable, Codable, Sendable {
    case active
    case archived
    case deleted
}
