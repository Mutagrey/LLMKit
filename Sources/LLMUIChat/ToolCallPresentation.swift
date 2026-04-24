import LLMCore

public struct ToolCallPresentation: Identifiable, Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case running
        case completed(String)
        case failed(String)
    }

    public let id: ToolCallID
    public let toolName: String
    public let arguments: ToolArguments
    public let status: Status

    public init(id: ToolCallID, toolName: String, arguments: ToolArguments, status: Status) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
        self.status = status
    }
}
