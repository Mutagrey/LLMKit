import Foundation

public struct ToolDefinition: Hashable, Codable, Sendable, Identifiable {
    public var id: String { name }

    public let name: String
    public let description: String
    public let schema: ToolSchema
    public let permission: ToolPermission

    public init(name: String, description: String, schema: ToolSchema = ToolSchema(), permission: ToolPermission = .automatic) {
        self.name = name
        self.description = description
        self.schema = schema
        self.permission = permission
    }
}

public struct ToolSchema: Hashable, Codable, Sendable {
    public let requiredArguments: [String]
    public let argumentDescriptions: [String: String]

    public init(requiredArguments: [String] = [], argumentDescriptions: [String: String] = [:]) {
        self.requiredArguments = requiredArguments
        self.argumentDescriptions = argumentDescriptions
    }
}

public enum ToolPermission: Hashable, Codable, Sendable {
    case automatic
    case requiresApproval
    case denied
}

public struct ToolArguments: Hashable, Codable, Sendable {
    public let values: [String: String]

    public init(values: [String: String] = [:]) {
        self.values = values
    }
}

public struct ToolInvocation: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let toolName: String
    public let arguments: ToolArguments

    public init(id: UUID = UUID(), toolName: String, arguments: ToolArguments = ToolArguments()) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
    }
}

public struct ToolResult: Hashable, Codable, Sendable {
    public let invocationID: UUID
    public let content: String
    public let isError: Bool

    public init(invocationID: UUID, content: String, isError: Bool = false) {
        self.invocationID = invocationID
        self.content = content
        self.isError = isError
    }
}
