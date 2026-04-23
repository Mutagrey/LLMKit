import Foundation

public enum MessageRole: String, Hashable, Codable, Sendable {
    case system
    case developer
    case user
    case assistant
    case tool
}

public struct MessageContent: Hashable, Codable, Sendable {
    public let text: String
    public let attachments: [AttachmentReference]

    public init(text: String, attachments: [AttachmentReference] = []) {
        self.text = text
        self.attachments = attachments
    }
}

public struct AttachmentReference: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let contentType: String
    public let displayName: String?
    public let uri: URL?

    public init(id: UUID = UUID(), contentType: String, displayName: String? = nil, uri: URL? = nil) {
        self.id = id
        self.contentType = contentType
        self.displayName = displayName
        self.uri = uri
    }
}

public struct ChatMessage: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let role: MessageRole
    public let content: MessageContent
    public let createdAt: Date
    public let toolCallReference: ToolCallReference?

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: MessageContent,
        createdAt: Date = Date(),
        toolCallReference: ToolCallReference? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.toolCallReference = toolCallReference
    }

    public init(id: UUID = UUID(), role: MessageRole, content: MessageContent, createdAt: Date = Date()) {
        self.init(
            id: id,
            role: role,
            content: content,
            createdAt: createdAt,
            toolCallReference: nil
        )
    }
}

public struct ConversationTurn: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let messages: [ChatMessage]

    public init(id: UUID = UUID(), messages: [ChatMessage]) {
        self.id = id
        self.messages = messages
    }
}
