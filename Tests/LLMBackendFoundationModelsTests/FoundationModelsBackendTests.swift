@testable import LLMBackendFoundationModels
import LLMCore
import LLMProtocols
import Testing

@Test func foundationModelsBackendReportsKind() {
    #expect(FoundationModelsBackend().backendKind == .foundationModels)
}

@Test func foundationModelsBackendReportsConfiguredAvailability() async throws {
    let descriptor = ModelDescriptor(
        id: "foundation-model",
        displayName: "Foundation Model",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.completion]
    )
    let unavailableBackend = FoundationModelsBackend(runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: false, reason: "not ready"))
    let unavailable = await unavailableBackend.availability(for: descriptor)
    let availableBackend = FoundationModelsBackend(runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: true))
    let handle = try await availableBackend.loadModel(descriptor)

    #expect(unavailable.status != .available)
    #expect(await availableBackend.availability(for: descriptor).status == .available)
    #expect(handle.backend == .foundationModels)
}

@Test func foundationModelsBackendRejectsWrongBackendDescriptor() async throws {
    let descriptor = ModelDescriptor(id: "remote", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let backend = FoundationModelsBackend(runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: true))

    let availability = await backend.availability(for: descriptor)

    #expect(availability.status == .unsupported)
    do {
        _ = try await backend.loadModel(descriptor)
        Issue.record("Expected Foundation Models backend to reject non-foundation descriptor.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}

@Test func foundationModelsGenerationFailsWhenRuntimeUnavailable() async throws {
    let descriptor = ModelDescriptor(id: "foundation", displayName: "Foundation", family: .appleFoundation, backend: .foundationModels, capabilities: [.completion])
    let backend = FoundationModelsBackend(runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: false, reason: "not ready"))

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: descriptor)) {}
        Issue.record("Expected Foundation Models generation to fail when runtime is unavailable.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}

@Test func foundationModelsChatFailsWhenRuntimeUnavailable() async throws {
    let descriptor = ModelDescriptor(id: "foundation", displayName: "Foundation", family: .appleFoundation, backend: .foundationModels, capabilities: [.chat])
    let backend = FoundationModelsBackend(runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: false, reason: "not ready"))
    let request = ChatRequest(messages: [
        ChatMessage(role: .user, content: MessageContent(text: "hello"))
    ])

    do {
        for try await _ in backend.chat(BackendChatRequest(request: request, model: descriptor)) {}
        Issue.record("Expected Foundation Models chat to fail when runtime is unavailable.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}

@Test func foundationModelsStructuredOutputMapperBuildsPlanForObjectSchema() throws {
    let schema = StructuredOutputSchema(name: "WeatherSummary", definition: [
        "type": .string("object"),
        "properties": .object([
            "city": .object(["type": .string("string")]),
            "temperature": .object(["type": .string("number")]),
            "tags": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "condition": .object([
                "enum": .array([.string("sunny"), .string("cloudy")])
            ])
        ]),
        "required": .array([.string("city"), .string("condition")])
    ])

    let plan = try FoundationModelsStructuredOutputMapper.plan(for: schema)

    #expect(plan.rootName == "WeatherSummary")
    #expect(plan.rootNode == .object([
        StructuredSchemaProperty(name: "city", isOptional: false, node: .string),
        StructuredSchemaProperty(name: "condition", isOptional: false, node: .stringEnum(["sunny", "cloudy"])),
        StructuredSchemaProperty(name: "tags", isOptional: true, node: .array(.string)),
        StructuredSchemaProperty(name: "temperature", isOptional: true, node: .number)
    ]))
}

@Test func foundationModelsStructuredOutputMapperRejectsUnsupportedNullSchemaNodes() throws {
    let schema = StructuredOutputSchema(name: "NullRoot", definition: [
        "type": .string("null")
    ])

    #expect(throws: BackendError.self) {
        _ = try FoundationModelsStructuredOutputMapper.plan(for: schema)
    }
}
