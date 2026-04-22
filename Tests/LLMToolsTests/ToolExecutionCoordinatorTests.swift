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

@Test func toolCoordinatorFailsForUnregisteredTool() async throws {
    let coordinator = ToolExecutionCoordinator(registry: DefaultToolRegistry())
    let invocation = ToolInvocation(toolName: "missing")

    do {
        _ = try await coordinator.execute(invocation)
        Issue.record("Expected unregistered tool execution to fail.")
    } catch {
        #expect(error as? LLMError == .toolExecutionFailed("Tool not registered: missing"))
    }
}

@Test func toolCoordinatorValidatesRequiredArgumentsBeforeExecution() async throws {
    let definition = ToolDefinition(
        name: "echo",
        description: "Echo input",
        schema: ToolSchema(requiredArguments: ["text"])
    )
    let registry = DefaultToolRegistry(entries: [
        (definition, ClosureToolExecutor { invocation in
            ToolResult(invocationID: invocation.id, content: "should not execute")
        })
    ])
    let coordinator = ToolExecutionCoordinator(registry: registry)

    do {
        _ = try await coordinator.execute(ToolInvocation(toolName: "echo"))
        Issue.record("Expected missing required argument to fail validation.")
    } catch {
        #expect(error as? ValidationError == .missingRequiredValue("text"))
    }
}

@Test func toolRegistryReturnsToolsSortedByName() async {
    let zTool = ToolDefinition(name: "zeta", description: "Z")
    let aTool = ToolDefinition(name: "alpha", description: "A")
    let registry = DefaultToolRegistry(entries: [
        (zTool, ClosureToolExecutor { ToolResult(invocationID: $0.id, content: "") }),
        (aTool, ClosureToolExecutor { ToolResult(invocationID: $0.id, content: "") })
    ])

    let tools = await registry.allTools()

    #expect(tools.map(\.name) == ["alpha", "zeta"])
}

@Test func toolRegistryReplacesDefinitionAndExecutorWithSameName() async throws {
    let first = ToolDefinition(name: "echo", description: "First")
    let second = ToolDefinition(name: "echo", description: "Second")
    let registry = DefaultToolRegistry(entries: [
        (first, ClosureToolExecutor { ToolResult(invocationID: $0.id, content: "first") })
    ])

    await registry.register(
        definition: second,
        executor: ClosureToolExecutor { ToolResult(invocationID: $0.id, content: "second") }
    )

    let tools = await registry.allTools()
    let executor = try #require(await registry.executor(for: "echo"))
    let result = try await executor.execute(ToolInvocation(toolName: "echo"))

    #expect(tools == [second])
    #expect(result.content == "second")
}
