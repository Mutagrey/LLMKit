import LLMCore

public protocol ToolService: Sendable {
    func availableTools() async -> [ToolDefinition]
    func execute(_ invocation: ToolInvocation) async throws -> ToolResult
}
