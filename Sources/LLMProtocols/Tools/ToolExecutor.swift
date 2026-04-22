import LLMCore

public protocol ToolExecutor: Sendable {
    func execute(_ invocation: ToolInvocation) async throws -> ToolResult
}

public protocol ToolRegistryProviding: Sendable {
    func allTools() async -> [ToolDefinition]
    func executor(for toolName: String) async -> (any ToolExecutor)?
}

public protocol ToolArgumentValidator: Sendable {
    func validate(_ arguments: ToolArguments, for definition: ToolDefinition) throws
}
