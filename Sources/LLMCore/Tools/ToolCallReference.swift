import Foundation

public struct ToolCallReference: Hashable, Codable, Sendable {
    public let id: ToolCallID
    public let toolName: String

    public init(id: ToolCallID, toolName: String) {
        self.id = id
        self.toolName = toolName
    }
}
