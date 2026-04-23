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
    private let storage: [String: ToolValue]

    public init(values: [String: String] = [:]) {
        self.storage = values.mapValues(ToolValue.string)
    }

    public init(structuredValues: [String: ToolValue]) {
        self.storage = structuredValues
    }

    public var values: [String: String] {
        storage.mapValues(\.stringValue)
    }

    public var structuredValues: [String: ToolValue] {
        storage
    }

    public subscript(argumentName: String) -> ToolValue? {
        storage[argumentName]
    }

    public func contains(_ argumentName: String) -> Bool {
        storage[argumentName] != nil
    }

    enum CodingKeys: String, CodingKey {
        case values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.storage = try container.decode([String: ToolValue].self, forKey: .values)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(storage, forKey: .values)
    }
}

public struct ToolInvocation: Hashable, Codable, Sendable, Identifiable {
    public let id: ToolCallID
    public let toolName: String
    public let arguments: ToolArguments

    public init(id: ToolCallID = .generated(), toolName: String, arguments: ToolArguments = ToolArguments()) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
    }
}

public struct ToolResult: Hashable, Codable, Sendable {
    public let invocationID: ToolCallID
    public let content: String
    public let isError: Bool

    public init(invocationID: ToolCallID, content: String, isError: Bool = false) {
        self.invocationID = invocationID
        self.content = content
        self.isError = isError
    }
}
