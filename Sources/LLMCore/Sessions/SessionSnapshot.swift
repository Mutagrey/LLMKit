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
    public let messages: [ChatMessage]
    public let summary: SessionSummary?

    public init(id: SessionID, descriptor: SessionDescriptor, messages: [ChatMessage] = [], summary: SessionSummary? = nil) {
        self.id = id
        self.descriptor = descriptor
        self.messages = messages
        self.summary = summary
    }
}

public enum SessionState: Hashable, Codable, Sendable {
    case active
    case archived
    case deleted
}
