import LLMCore
import LLMProtocols

public struct RequiredArgumentValidator: ToolArgumentValidator {
    public init() {}

    public func validate(_ arguments: ToolArguments, for definition: ToolDefinition) throws {
        for key in definition.schema.requiredArguments where arguments.values[key] == nil {
            throw ValidationError.missingRequiredValue(key)
        }
    }
}

public struct ToolExecutionCoordinator: ToolService {
    private let registry: any ToolRegistryProviding
    private let validator: any ToolArgumentValidator

    public init(registry: any ToolRegistryProviding, validator: any ToolArgumentValidator = RequiredArgumentValidator()) {
        self.registry = registry
        self.validator = validator
    }

    public func availableTools() async -> [ToolDefinition] {
        await registry.allTools()
    }

    public func execute(_ invocation: ToolInvocation) async throws -> ToolResult {
        let tools = await registry.allTools()
        guard let definition = tools.first(where: { $0.name == invocation.toolName }) else {
            throw LLMError.toolExecutionFailed("Tool not registered: \(invocation.toolName)")
        }
        try validator.validate(invocation.arguments, for: definition)
        guard let executor = await registry.executor(for: invocation.toolName) else {
            throw LLMError.toolExecutionFailed("Executor not registered: \(invocation.toolName)")
        }
        return try await executor.execute(invocation)
    }
}
