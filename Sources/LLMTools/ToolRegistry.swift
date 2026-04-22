import LLMCore
import LLMProtocols

public struct ClosureToolExecutor: ToolExecutor {
    private let handler: @Sendable (ToolInvocation) async throws -> ToolResult

    public init(handler: @escaping @Sendable (ToolInvocation) async throws -> ToolResult) {
        self.handler = handler
    }

    public func execute(_ invocation: ToolInvocation) async throws -> ToolResult {
        try await handler(invocation)
    }
}

public actor DefaultToolRegistry: ToolRegistryProviding {
    private var definitions: [String: ToolDefinition]
    private var executors: [String: any ToolExecutor]

    public init(entries: [(ToolDefinition, any ToolExecutor)] = []) {
        self.definitions = Dictionary(uniqueKeysWithValues: entries.map { ($0.0.name, $0.0) })
        self.executors = Dictionary(uniqueKeysWithValues: entries.map { ($0.0.name, $0.1) })
    }

    public func register(definition: ToolDefinition, executor: any ToolExecutor) {
        definitions[definition.name] = definition
        executors[definition.name] = executor
    }

    public func allTools() async -> [ToolDefinition] {
        Array(definitions.values).sorted { $0.name < $1.name }
    }

    public func executor(for toolName: String) async -> (any ToolExecutor)? {
        executors[toolName]
    }
}
