import LLMBackendFoundationModels
import LLMCore
import Testing

@Test func foundationModelsPromptMapperIncludesToolDefinitionsInInstructions() {
    let request = ChatRequest(
        messages: [
            ChatMessage(role: .system, content: MessageContent(text: "Be concise")),
            ChatMessage(role: .user, content: MessageContent(text: "What is the weather?"))
        ],
        tools: [
            ToolDefinition(
                name: "weather",
                description: "Lookup weather forecast",
                schema: ToolSchema(
                    requiredArguments: ["city"],
                    argumentDescriptions: ["city": "City name"]
                )
            )
        ]
    )

    let mapped = FoundationModelsPromptMapper.prompt(for: request)

    #expect(mapped.instructions == """
    Available Tools:
    - weather: Lookup weather forecast | required=city | arguments=city=City name

    Be concise
    """)
    #expect(mapped.prompt == "User: What is the weather?")
}

@Test func foundationModelsPromptMapperPreservesToolResultReferencesInPrompt() {
    let request = ChatRequest(messages: [
        ChatMessage(role: .user, content: MessageContent(text: "Run weather")),
        ChatMessage(
            role: .tool,
            content: MessageContent(text: "{\"forecast\":\"sunny\"}"),
            toolCallReference: ToolCallReference(id: "call_weather_1", toolName: "weather")
        )
    ])

    let mapped = FoundationModelsPromptMapper.prompt(for: request)

    #expect(mapped.instructions == nil)
    #expect(mapped.prompt == """
    User: Run weather

    Tool[weather#call_weather_1]: {"forecast":"sunny"}
    """)
}
