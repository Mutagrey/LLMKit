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

@Test func foundationModelsBackendSurfacesLocaleFailureFromAvailability() async throws {
    let descriptor = ModelDescriptor(
        id: "foundation-model",
        displayName: "Foundation Model",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.chat]
    )
    let message = "Apple Intelligence does not support the current locale (ru_RU)."
    let backend = FoundationModelsBackend(
        runtimeAvailability: FoundationModelsRuntimeAvailability(
            isAvailable: false,
            reason: message,
            failure: .unsupportedLocale(message)
        )
    )

    let availability = await backend.availability(for: descriptor)

    #expect(availability.failure == .unsupportedLocale(message))
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

@Test func foundationModelsGenerationStreamsMultipleDeltasBeforeCompletion() async throws {
    let descriptor = ModelDescriptor(id: "foundation", displayName: "Foundation", family: .appleFoundation, backend: .foundationModels, capabilities: [.completion, .streaming])
    let backend = FoundationModelsBackend(
        runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: true),
        runtime: FakeFoundationModelsRuntime(generationDeltas: ["hel", "lo"])
    )

    var didStart = false
    var deltas: [String] = []
    var completedText: String?
    for try await event in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: descriptor)) {
        switch event {
        case .started(let model):
            didStart = model == descriptor
        case .delta(let text):
            deltas.append(text)
        case .completed(let result):
            completedText = result.text
        case .failed:
            Issue.record("Foundation Models fake runtime should not emit a failure event.")
        }
    }

    #expect(didStart)
    #expect(deltas == ["hel", "lo"])
    #expect(completedText == "hello")
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

@Test func foundationModelsChatStreamsMultipleDeltasBeforeCompletion() async throws {
    let descriptor = ModelDescriptor(id: "foundation", displayName: "Foundation", family: .appleFoundation, backend: .foundationModels, capabilities: [.chat, .streaming])
    let request = ChatRequest(messages: [
        ChatMessage(role: .user, content: MessageContent(text: "hello"))
    ])
    let backend = FoundationModelsBackend(
        runtimeAvailability: FoundationModelsRuntimeAvailability(isAvailable: true),
        runtime: FakeFoundationModelsRuntime(chatDeltas: ["he", "llo"])
    )

    var deltas: [String] = []
    var completedMessage: ChatMessage?
    for try await event in backend.chat(BackendChatRequest(request: request, model: descriptor)) {
        switch event {
        case .started:
            break
        case .delta(let text):
            deltas.append(text)
        case .completed(let result):
            completedMessage = result.message
        case .toolCallRequested, .toolCallCompleted, .failed:
            Issue.record("Foundation Models fake runtime should only emit text events.")
        }
    }

    #expect(deltas == ["he", "llo"])
    #expect(completedMessage?.role == .assistant)
    #expect(completedMessage?.content.text == "hello")
}

@Test func foundationModelsStreamDeltaReducerConvertsCumulativeSnapshotsToDeltas() {
    var reducer = FoundationModelsStreamDeltaReducer()

    #expect(reducer.delta(from: "") == nil)
    #expect(reducer.delta(from: "hel") == "hel")
    #expect(reducer.delta(from: "hello") == "lo")
    #expect(reducer.delta(from: "hello") == nil)
}

@Test func foundationModelsStreamDeltaReducerHandlesUnicodeBoundaries() {
    var reducer = FoundationModelsStreamDeltaReducer()

    #expect(reducer.delta(from: "👨‍💻") == "👨‍💻")
    #expect(reducer.delta(from: "👨‍💻 готов") == " готов")
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

private struct FakeFoundationModelsRuntime: FoundationModelsRuntime {
    var generationDeltas: [String] = []
    var chatDeltas: [String] = []

    func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<String, Error> {
        stream(generationDeltas)
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<String, Error> {
        stream(chatDeltas)
    }

    private func stream(_ deltas: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for delta in deltas {
                continuation.yield(delta)
            }
            continuation.finish()
        }
    }
}
