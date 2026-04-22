import LLMCore
import LLMTools
import Testing

@Test func toolCoordinatorExecutesRegisteredTool() async throws {
    let definition = ToolDefinition(
        name: "echo",
        description: "Echo input",
        schema: ToolSchema(requiredArguments: ["text"])
    )
    let registry = DefaultToolRegistry(entries: [
        (definition, ClosureToolExecutor { invocation in
            ToolResult(invocationID: invocation.id, content: invocation.arguments.values["text"] ?? "")
        })
    ])
    let coordinator = ToolExecutionCoordinator(registry: registry)
    let invocation = ToolInvocation(toolName: "echo", arguments: ToolArguments(values: ["text": "hello"]))

    let result = try await coordinator.execute(invocation)

    #expect(result.content == "hello")
}
