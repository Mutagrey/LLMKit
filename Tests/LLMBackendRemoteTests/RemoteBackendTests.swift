import Foundation
@testable import LLMBackendRemote
import LLMCore
import LLMNetworking
import LLMProtocols
import Testing

private actor RecordingTransport: HTTPTransport {
    private(set) var requests: [HTTPRequest] = []
    private let responseBody: String
    private let statusCode: Int
    private let responseHeaders: [String: String]

    init(
        responseBody: String = #"{"choices":[{"text":"remote hello"}]}"#,
        statusCode: Int = 200,
        responseHeaders: [String: String] = [:]
    ) {
        self.responseBody = responseBody
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let body = responseBody.data(using: .utf8) ?? Data()
        return HTTPResponse(statusCode: statusCode, headers: responseHeaders, body: body)
    }
}

private actor StreamingRecordingTransport: HTTPStreamingTransport {
    private(set) var requests: [HTTPRequest] = []
    private let chunks: [String]
    private let statusCode: Int

    init(chunks: [String], statusCode: Int = 200) {
        self.chunks = chunks
        self.statusCode = statusCode
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        return HTTPResponse(statusCode: statusCode, body: Data(chunks.joined().utf8))
    }

    nonisolated func stream(_ request: HTTPRequest) -> AsyncThrowingStream<HTTPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await record(request)
                continuation.yield(.response(HTTPResponseHead(statusCode: statusCode)))
                for chunk in chunks {
                    continuation.yield(.body(Data(chunk.utf8)))
                }
                continuation.finish()
            }
        }
    }

    private func record(_ request: HTTPRequest) {
        requests.append(request)
    }
}

@Test func remoteConfigurationStoresProviderID() throws {
    let url = try #require(URL(string: "https://example.com"))
    let configuration = RemoteConfiguration(providerID: "test", baseURL: url)

    #expect(configuration.providerID.rawValue == "test")
}

@Test func openAIConfigurationStoresProviderHeadersAndPaths() {
    let configuration = RemoteConfiguration.openAI(
        apiKey: "test-key",
        organizationID: "org-test",
        projectID: "proj-test"
    )

    #expect(configuration.providerID.rawValue == "openai")
    #expect(configuration.baseURL.absoluteString == "https://api.openai.com/v1")
    #expect(configuration.generationPath == "chat/completions")
    #expect(configuration.chatPath == "chat/completions")
    #expect(configuration.apiStyle == .openAIChatCompletions)
    #expect(configuration.defaultHeaders["Authorization"] == "Bearer test-key")
    #expect(configuration.defaultHeaders["OpenAI-Organization"] == "org-test")
    #expect(configuration.defaultHeaders["OpenAI-Project"] == "proj-test")
}

@Test func openAIResponsesConfigurationStoresProviderHeadersAndPaths() {
    let configuration = RemoteConfiguration.openAIResponses(apiKey: "test-key")

    #expect(configuration.providerID.rawValue == "openai")
    #expect(configuration.baseURL.absoluteString == "https://api.openai.com/v1")
    #expect(configuration.generationPath == "responses")
    #expect(configuration.chatPath == "responses")
    #expect(configuration.apiStyle == .openAIResponses)
    #expect(configuration.defaultHeaders["Authorization"] == "Bearer test-key")
}

@Test func anthropicConfigurationStoresProviderHeadersAndPaths() {
    let configuration = RemoteConfiguration.anthropic(apiKey: "test-key", defaultMaxTokens: 2048)

    #expect(configuration.providerID.rawValue == "anthropic")
    #expect(configuration.baseURL.absoluteString == "https://api.anthropic.com/v1")
    #expect(configuration.generationPath == "messages")
    #expect(configuration.chatPath == "messages")
    #expect(configuration.apiStyle == .anthropicMessages(defaultMaxTokens: 2048))
    #expect(configuration.defaultHeaders["x-api-key"] == "test-key")
    #expect(configuration.defaultHeaders["anthropic-version"] == "2023-06-01")
}

@Test func openAIChatCompletionsDescriptorBuildsRemoteModelMetadata() {
    let descriptor = RemoteModelDescriptors.openAIChatCompletions(
        id: "gpt-test",
        displayName: "GPT Test",
        contextWindowTokens: 128_000,
        supportsTools: true,
        supportsStructuredOutput: true,
        extraCapabilities: [.summarization],
        tags: ["production"]
    )

    #expect(descriptor.id.rawValue == "gpt-test")
    #expect(descriptor.displayName == "GPT Test")
    #expect(descriptor.family == .custom("openai"))
    #expect(descriptor.backend == .remote)
    #expect(descriptor.isRemote)
    #expect(descriptor.supportsStreaming)
    #expect(descriptor.supportsTools)
    #expect(descriptor.supportsStructuredOutput)
    #expect(descriptor.contextWindowTokens == 128_000)
    #expect(descriptor.capabilities.isSuperset(of: [.chat, .completion, .streaming, .toolCalling, .structuredOutput, .summarization]))
    #expect(descriptor.tags == ["provider:openai", "api:chat-completions", "production"])
}

@Test func openAIResponsesDescriptorBuildsRemoteModelMetadata() {
    let descriptor = RemoteModelDescriptors.openAIResponses(
        id: "gpt-responses-test",
        supportsTools: true,
        supportsStructuredOutput: true
    )

    #expect(descriptor.id.rawValue == "gpt-responses-test")
    #expect(descriptor.family == .custom("openai"))
    #expect(descriptor.backend == .remote)
    #expect(descriptor.isRemote)
    #expect(descriptor.supportsStreaming)
    #expect(descriptor.supportsTools)
    #expect(descriptor.supportsStructuredOutput)
    #expect(descriptor.capabilities.isSuperset(of: [.chat, .completion, .streaming, .toolCalling, .structuredOutput]))
    #expect(descriptor.tags == ["provider:openai", "api:responses"])
}

@Test func anthropicMessagesDescriptorBuildsRemoteModelMetadata() {
    let descriptor = RemoteModelDescriptors.anthropicMessages(
        id: "claude-test",
        supportsTools: true,
        extraCapabilities: [.longContext]
    )

    #expect(descriptor.id.rawValue == "claude-test")
    #expect(descriptor.displayName == "claude-test")
    #expect(descriptor.family == .custom("anthropic"))
    #expect(descriptor.backend == .remote)
    #expect(descriptor.isRemote)
    #expect(descriptor.supportsStreaming)
    #expect(descriptor.supportsTools)
    #expect(!descriptor.supportsStructuredOutput)
    #expect(descriptor.capabilities.isSuperset(of: [.chat, .completion, .streaming, .toolCalling, .longContext]))
    #expect(!descriptor.capabilities.contains(.structuredOutput))
    #expect(descriptor.tags == ["provider:anthropic", "api:messages"])
}

@Test func openAIResponsesGenerationUsesResponsesRequestBody() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let responseBody = #"{"output":[{"type":"message","content":[{"type":"output_text","text":"responses hello"}]}],"usage":{"input_tokens":4,"output_tokens":2,"total_tokens":6}}"#
    let transport = RecordingTransport(responseBody: responseBody)
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.openAIResponses(apiKey: "token", baseURL: url),
        transport: transport
    )
    let model = RemoteModelDescriptors.openAIResponses(id: "gpt-responses-test")

    var completed: GenerationResult?
    for try await event in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    let request = try #require(await transport.requests.first)
    let body = try decodeOpenAIResponsesGenerationRequest(request)

    #expect(completed?.text == "responses hello")
    #expect(completed?.usage?.tokens.inputTokens == 4)
    #expect(completed?.usage?.tokens.outputTokens == 2)
    #expect(completed?.usage?.tokens.totalTokens == 6)
    #expect(request.url.absoluteString == "https://example.com/v1/responses")
    #expect(request.headers["Authorization"] == "Bearer token")
    #expect(body.model == "gpt-responses-test")
    #expect(body.input == "hello")
    #expect(body.stream == true)
    #expect(body.text == nil)
}

@Test func openAIResponsesStructuredOutputMapperBuildsNativeFormat() throws {
    let schema = StructuredOutputSchema(name: "Weather Summary", definition: [
        "type": .string("object"),
        "properties": .object([
            "city": .object(["type": .string("string")])
        ]),
        "required": .array([.string("city")]),
        "additionalProperties": .boolean(false)
    ])
    let text = try #require(OpenAIResponsesStructuredOutputMapper.textConfiguration(for: schema))
    let format = text.format

    #expect(format.type == "json_schema")
    #expect(format.name == "Weather_Summary")
    #expect(format.strict == true)
    #expect(format.schema["type"] == .string("object"))
    #expect(format.schema["required"] == .array([.string("city")]))
}

@Test func remoteBackendSendsGenerationRequestThroughTransport() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let configuration = RemoteConfiguration(providerID: "test", baseURL: url, defaultHeaders: ["Authorization": "Bearer token"])
    let transport = RecordingTransport()
    let backend = RemoteBackend(configuration: configuration, transport: transport)
    let model = ModelDescriptor(id: "remote-model", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let request = BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)

    var completed: GenerationResult?
    for try await event in backend.generate(request) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    let requests = await transport.requests
    #expect(completed?.text == "remote hello")
    #expect(requests.first?.method == .post)
    #expect(requests.first?.url.absoluteString == "https://example.com/v1/completions")
    #expect(requests.first?.headers["Authorization"] == "Bearer token")
}

@Test func remoteBackendStreamsRemoteDeltasBeforeCompletion() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let transport = StreamingRecordingTransport(chunks: [
        #"data: {"choices":[{"text":"hel"}]}"# + "\n\n",
        #"data: {"choices":[{"text":"lo","finish_reason":"stop"}]}"# + "\n\n",
        "data: [DONE]\n\n"
    ])
    let backend = RemoteBackend(
        configuration: RemoteConfiguration(providerID: "test", baseURL: url),
        transport: transport
    )
    let model = ModelDescriptor(
        id: "remote-model",
        displayName: "Remote",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.completion, .streaming],
        supportsStreaming: true,
        isRemote: true
    )

    var deltas: [String] = []
    var completed: GenerationResult?
    for try await event in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {
        switch event {
        case .delta(let text):
            deltas.append(text)
        case .completed(let result):
            completed = result
        case .started, .failed:
            break
        }
    }

    #expect(deltas == ["hel", "lo"])
    #expect(completed?.text == "hello")
    #expect(await transport.requests.count == 1)
}

@Test func remoteBackendMapsGenerationRequestBody() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let transport = RecordingTransport()
    let backend = RemoteBackend(
        configuration: RemoteConfiguration(providerID: "test", baseURL: url),
        transport: transport
    )
    let model = ModelDescriptor(
        id: "remote-model",
        displayName: "Remote",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.completion],
        supportsStreaming: true,
        isRemote: true
    )

    for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {}

    let request = try #require(await transport.requests.first)
    let body = try requestBodyDictionary(request)

    #expect(body["model"] as? String == "remote-model")
    #expect(body["prompt"] as? String == "hello")
    #expect(body["stream"] as? Bool == true)
}

@Test func openAIGenerationUsesChatCompletionsRequestBody() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let transport = RecordingTransport(responseBody: #"{"choices":[{"message":{"content":"openai hello"}}]}"#)
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.openAI(apiKey: "token", baseURL: url),
        transport: transport
    )
    let model = ModelDescriptor(
        id: "gpt-test",
        displayName: "GPT Test",
        family: .custom("openai"),
        backend: .remote,
        capabilities: [.completion],
        supportsStreaming: true,
        isRemote: true
    )

    var completed: GenerationResult?
    for try await event in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    let request = try #require(await transport.requests.first)
    let body = try requestBodyDictionary(request)
    let messages = try #require(body["messages"] as? [[String: String]])

    #expect(completed?.text == "openai hello")
    #expect(request.url.absoluteString == "https://example.com/v1/chat/completions")
    #expect(request.headers["Authorization"] == "Bearer token")
    #expect(body["model"] as? String == "gpt-test")
    #expect(body["stream"] as? Bool == true)
    #expect(messages == [["role": "user", "content": "hello"]])
    #expect(body["response_format"] == nil)
    #expect(body["prompt"] == nil)
}

@Test func openAIChatCompletionsStructuredOutputMapperBuildsNativeFormat() throws {
    let schema = StructuredOutputSchema(name: "Weather Summary", definition: [
        "type": .string("object"),
        "properties": .object([
            "city": .object(["type": .string("string")])
        ]),
        "required": .array([.string("city")]),
        "additionalProperties": .boolean(false)
    ])
    let format = try #require(OpenAIChatCompletionsStructuredOutputMapper.responseFormat(for: schema))

    #expect(format.type == "json_schema")
    #expect(format.jsonSchema.name == "Weather_Summary")
    #expect(format.jsonSchema.strict == true)
    #expect(format.jsonSchema.schema["type"] == .string("object"))
    #expect(format.jsonSchema.schema["required"] == .array([.string("city")]))
}

@Test func openAIResponsesChatMapsMessagesAndInstructions() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let responseBody = #"{"output":[{"type":"message","content":[{"type":"output_text","text":"chat hello"}]}]}"#
    let transport = RecordingTransport(responseBody: responseBody)
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.openAIResponses(apiKey: "token", baseURL: url),
        transport: transport
    )
    let model = RemoteModelDescriptors.openAIResponses(id: "gpt-responses-chat")
    let messages = [
        ChatMessage(role: .system, content: MessageContent(text: "be concise")),
        ChatMessage(role: .developer, content: MessageContent(text: "prefer bullets")),
        ChatMessage(role: .user, content: MessageContent(text: "hello")),
        ChatMessage(role: .assistant, content: MessageContent(text: "hi")),
        ChatMessage(role: .user, content: MessageContent(text: "continue"))
    ]

    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: messages), model: model)) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    let request = try #require(await transport.requests.first)
    let body = try requestBodyDictionary(request)
    let mappedMessages = try #require(body["input"] as? [[String: String]])

    #expect(completed?.message.content.text == "chat hello")
    #expect(body["instructions"] as? String == "be concise\n\nprefer bullets")
    #expect(mappedMessages == [
        ["role": "user", "content": "hello"],
        ["role": "assistant", "content": "hi"],
        ["role": "user", "content": "continue"]
    ])
}

@Test func openAIResponsesChatMapsToolsAndToolResultMessages() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let responseBody = #"{"output":[{"type":"message","content":[{"type":"output_text","text":"done"}]}]}"#
    let transport = RecordingTransport(responseBody: responseBody)
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.openAIResponses(apiKey: "token", baseURL: url),
        transport: transport
    )
    let model = RemoteModelDescriptors.openAIResponses(id: "gpt-responses-chat", supportsTools: true)
    let tool = ToolDefinition(
        name: "weather",
        description: "Lookup weather",
        schema: ToolSchema(requiredArguments: ["city"], argumentDescriptions: ["city": "City name"])
    )
    let messages = [
        ChatMessage(role: .user, content: MessageContent(text: "what is the weather")),
        ChatMessage(
            role: .tool,
            content: MessageContent(text: "{\"forecast\":\"sunny\"}"),
            toolCallReference: ToolCallReference(id: "call_weather_1", toolName: "weather")
        )
    ]

    for try await _ in backend.chat(BackendChatRequest(request: ChatRequest(messages: messages, tools: [tool]), model: model)) {}

    let request = try #require(await transport.requests.first)
    let body = try requestBodyDictionary(request)
    let input = try #require(body["input"] as? [[String: Any]])
    let tools = try #require(body["tools"] as? [[String: Any]])
    let firstTool = try #require(tools.first)
    let parameters = try #require(firstTool["parameters"] as? [String: Any])
    let properties = try #require(parameters["properties"] as? [String: Any])
    let city = try #require(properties["city"] as? [String: Any])

    #expect(input.count == 2)
    #expect(input[0]["role"] as? String == "user")
    #expect(input[0]["content"] as? String == "what is the weather")
    #expect(input[1]["type"] as? String == "function_call_output")
    #expect(input[1]["call_id"] as? String == "call_weather_1")
    #expect(input[1]["output"] as? String == #"{"forecast":"sunny"}"#)
    #expect(firstTool["type"] as? String == "function")
    #expect(firstTool["name"] as? String == "weather")
    #expect(firstTool["description"] as? String == "Lookup weather")
    #expect(parameters["type"] as? String == "object")
    #expect(Set(try #require(parameters["required"] as? [String])) == Set(["city"]))
    #expect(city["description"] as? String == "City name")
}

@Test func anthropicGenerationUsesMessagesRequestBody() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let responseBody = #"{"content":[{"type":"text","text":"anthropic hello"}],"stop_reason":"end_turn","usage":{"input_tokens":4,"output_tokens":2}}"#
    let transport = RecordingTransport(responseBody: responseBody)
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.anthropic(apiKey: "token", defaultMaxTokens: 512, baseURL: url),
        transport: transport
    )
    let model = ModelDescriptor(
        id: "claude-test",
        displayName: "Claude Test",
        family: .custom("anthropic"),
        backend: .remote,
        capabilities: [.completion],
        supportsStreaming: true,
        isRemote: true
    )

    var completed: GenerationResult?
    for try await event in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    let request = try #require(await transport.requests.first)
    let body = try requestBodyDictionary(request)
    let messages = try #require(body["messages"] as? [[String: String]])

    #expect(completed?.text == "anthropic hello")
    #expect(completed?.usage?.tokens.inputTokens == 4)
    #expect(completed?.usage?.tokens.outputTokens == 2)
    #expect(completed?.usage?.tokens.totalTokens == 6)
    #expect(completed?.finishReason == .stopped)
    #expect(request.url.absoluteString == "https://example.com/v1/messages")
    #expect(request.headers["x-api-key"] == "token")
    #expect(request.headers["anthropic-version"] == "2023-06-01")
    #expect(body["model"] as? String == "claude-test")
    #expect(body["max_tokens"] as? Int == 512)
    #expect(body["stream"] as? Bool == true)
    #expect(messages == [["role": "user", "content": "hello"]])
}

@Test func remoteBackendSendsChatRequestThroughTransport() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let configuration = RemoteConfiguration(providerID: "test", baseURL: url)
    let transport = RecordingTransport(responseBody: #"{"choices":[{"message":{"content":"chat hello"}}]}"#)
    let backend = RemoteBackend(configuration: configuration, transport: transport)
    let model = ModelDescriptor(id: "remote-model", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.chat], isRemote: true)
    let message = ChatMessage(role: .user, content: MessageContent(text: "hello"))
    let request = BackendChatRequest(request: ChatRequest(messages: [message]), model: model)

    var completed: ChatResult?
    for try await event in backend.chat(request) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    let requests = await transport.requests
    #expect(completed?.message.content.text == "chat hello")
    #expect(requests.first?.url.absoluteString == "https://example.com/v1/chat/completions")
}

@Test func anthropicChatMapsSystemMessagesToTopLevelSystem() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let responseBody = #"{"content":[{"type":"text","text":"chat hello"}],"stop_reason":"end_turn","usage":{"input_tokens":9,"output_tokens":2}}"#
    let transport = RecordingTransport(responseBody: responseBody)
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.anthropic(apiKey: "token", defaultMaxTokens: 256, baseURL: url),
        transport: transport
    )
    let model = ModelDescriptor(
        id: "claude-chat",
        displayName: "Claude Chat",
        family: .custom("anthropic"),
        backend: .remote,
        capabilities: [.chat],
        isRemote: true
    )
    let messages = [
        ChatMessage(role: .system, content: MessageContent(text: "be concise")),
        ChatMessage(role: .developer, content: MessageContent(text: "prefer bullets")),
        ChatMessage(role: .user, content: MessageContent(text: "hello")),
        ChatMessage(role: .assistant, content: MessageContent(text: "hi")),
        ChatMessage(role: .user, content: MessageContent(text: "continue"))
    ]

    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: messages), model: model)) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    let request = try #require(await transport.requests.first)
    let body = try requestBodyDictionary(request)
    let mappedMessages = try #require(body["messages"] as? [[String: String]])

    #expect(completed?.message.content.text == "chat hello")
    #expect(body["system"] as? String == "be concise\n\nprefer bullets")
    #expect(mappedMessages == [
        ["role": "user", "content": "hello"],
        ["role": "assistant", "content": "hi"],
        ["role": "user", "content": "continue"]
    ])
}

@Test func anthropicChatMapsToolsAndToolResultMessages() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let responseBody = #"{"content":[{"type":"text","text":"done"}],"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":1}}"#
    let transport = RecordingTransport(responseBody: responseBody)
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.anthropic(apiKey: "token", defaultMaxTokens: 256, baseURL: url),
        transport: transport
    )
    let model = RemoteModelDescriptors.anthropicMessages(id: "claude-chat", supportsTools: true)
    let tool = ToolDefinition(
        name: "weather",
        description: "Lookup weather",
        schema: ToolSchema(requiredArguments: ["city"], argumentDescriptions: ["city": "City name"])
    )
    let messages = [
        ChatMessage(role: .user, content: MessageContent(text: "weather")),
        ChatMessage(
            role: .tool,
            content: MessageContent(text: "sunny"),
            toolCallReference: ToolCallReference(id: "toolu_weather_1", toolName: "weather")
        )
    ]

    for try await _ in backend.chat(BackendChatRequest(request: ChatRequest(messages: messages, tools: [tool]), model: model)) {}

    let request = try #require(await transport.requests.first)
    let body = try requestBodyDictionary(request)
    let tools = try #require(body["tools"] as? [[String: Any]])
    let firstTool = try #require(tools.first)
    let inputSchema = try #require(firstTool["input_schema"] as? [String: Any])
    let properties = try #require(inputSchema["properties"] as? [String: Any])
    let city = try #require(properties["city"] as? [String: Any])
    let mappedMessages = try #require(body["messages"] as? [[String: Any]])
    let toolResultMessage = try #require(mappedMessages.last)
    let contentBlocks = try #require(toolResultMessage["content"] as? [[String: Any]])
    let firstBlock = try #require(contentBlocks.first)

    #expect(firstTool["name"] as? String == "weather")
    #expect(firstTool["description"] as? String == "Lookup weather")
    #expect(inputSchema["type"] as? String == "object")
    #expect(Set(try #require(inputSchema["required"] as? [String])) == Set(["city"]))
    #expect(city["description"] as? String == "City name")
    #expect(toolResultMessage["role"] as? String == "user")
    #expect(firstBlock["type"] as? String == "tool_result")
    #expect(firstBlock["tool_use_id"] as? String == "toolu_weather_1")
    #expect(firstBlock["text"] as? String == "sunny")
}

@Test func remoteBackendMapsChatRequestBody() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let transport = RecordingTransport(responseBody: #"{"choices":[{"message":{"content":"chat hello"}}]}"#)
    let backend = RemoteBackend(
        configuration: RemoteConfiguration(providerID: "test", baseURL: url),
        transport: transport
    )
    let model = ModelDescriptor(
        id: "remote-chat",
        displayName: "Remote Chat",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.chat],
        supportsStreaming: true,
        isRemote: true
    )
    let messages = [
        ChatMessage(role: .system, content: MessageContent(text: "be concise")),
        ChatMessage(role: .user, content: MessageContent(text: "hello"))
    ]

    for try await _ in backend.chat(BackendChatRequest(request: ChatRequest(messages: messages), model: model)) {}

    let request = try #require(await transport.requests.first)
    let body = try requestBodyDictionary(request)
    let mappedMessages = try #require(body["messages"] as? [[String: String]])

    #expect(body["model"] as? String == "remote-chat")
    #expect(body["stream"] as? Bool == true)
    #expect(mappedMessages == [
        ["role": "system", "content": "be concise"],
        ["role": "user", "content": "hello"]
    ])
}

@Test func anthropicBackendParsesStreamingChatEvents() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = """
    event: message_start
    data: {"type":"message_start","message":{"usage":{"input_tokens":5,"output_tokens":1}}}

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"he"}}

    event: ping
    data: {"type":"ping"}

    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"y"}}

    event: message_delta
    data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":3}}

    event: message_stop
    data: {"type":"message_stop"}

    """
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.anthropic(apiKey: "token", baseURL: url),
        transport: RecordingTransport(responseBody: body)
    )
    let model = ModelDescriptor(
        id: "claude-chat",
        displayName: "Claude Chat",
        family: .custom("anthropic"),
        backend: .remote,
        capabilities: [.chat],
        supportsStreaming: true,
        isRemote: true
    )
    let message = ChatMessage(role: .user, content: MessageContent(text: "hello"))

    var deltas: [String] = []
    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: [message]), model: model)) {
        switch event {
        case .delta(let text):
            deltas.append(text)
        case .completed(let result):
            completed = result
        case .started, .toolCallRequested, .toolCallCompleted, .failed:
            break
        }
    }

    #expect(deltas == ["he", "y"])
    #expect(completed?.message.content.text == "hey")
    #expect(completed?.finishReason == .stopped)
    #expect(completed?.usage?.tokens.inputTokens == 5)
    #expect(completed?.usage?.tokens.outputTokens == 3)
    #expect(completed?.usage?.tokens.totalTokens == 8)
}

@Test func remoteBackendParsesStreamingGenerationEvents() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = """
    data: {"choices":[{"text":"hel"}]}

    data: {"choices":[{"text":"lo"}]}

    data: [DONE]

    """
    let backend = RemoteBackend(
        configuration: RemoteConfiguration(providerID: "test", baseURL: url),
        transport: RecordingTransport(responseBody: body)
    )
    let model = ModelDescriptor(
        id: "remote-model",
        displayName: "Remote",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.completion],
        supportsStreaming: true,
        isRemote: true
    )

    var deltas: [String] = []
    var completed: GenerationResult?
    for try await event in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {
        switch event {
        case .delta(let text):
            deltas.append(text)
        case .completed(let result):
            completed = result
        case .started, .failed:
            break
        }
    }

    #expect(deltas == ["hel", "lo"])
    #expect(completed?.text == "hello")
}

@Test func openAIResponsesBackendParsesSemanticStreamingChatEvents() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = """
    event: response.created
    data: {"type":"response.created","response":{"usage":null}}

    event: response.output_text.delta
    data: {"type":"response.output_text.delta","delta":"he"}

    event: response.output_text.delta
    data: {"type":"response.output_text.delta","delta":"y"}

    event: response.completed
    data: {"type":"response.completed","response":{"usage":{"input_tokens":5,"output_tokens":3,"total_tokens":8}}}

    """
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.openAIResponses(apiKey: "token", baseURL: url),
        transport: RecordingTransport(responseBody: body)
    )
    let model = RemoteModelDescriptors.openAIResponses(id: "gpt-responses-chat")
    let message = ChatMessage(role: .user, content: MessageContent(text: "hello"))

    var deltas: [String] = []
    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: [message]), model: model)) {
        switch event {
        case .delta(let text):
            deltas.append(text)
        case .completed(let result):
            completed = result
        case .started, .toolCallRequested, .toolCallCompleted, .failed:
            break
        }
    }

    #expect(deltas == ["he", "y"])
    #expect(completed?.message.content.text == "hey")
    #expect(completed?.usage?.tokens.inputTokens == 5)
    #expect(completed?.usage?.tokens.outputTokens == 3)
    #expect(completed?.usage?.tokens.totalTokens == 8)
}

@Test func remoteBackendParsesStreamingChatEvents() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = """
    data: {"choices":[{"delta":{"content":"he"}}]}

    data: {"choices":[{"delta":{"content":"y"}}]}

    data: [DONE]

    """
    let backend = RemoteBackend(
        configuration: RemoteConfiguration(providerID: "test", baseURL: url),
        transport: RecordingTransport(responseBody: body)
    )
    let model = ModelDescriptor(
        id: "remote-model",
        displayName: "Remote",
        family: .custom("test"),
        backend: .remote,
        capabilities: [.chat],
        supportsStreaming: true,
        isRemote: true
    )
    let message = ChatMessage(role: .user, content: MessageContent(text: "hello"))

    var deltas: [String] = []
    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: [message]), model: model)) {
        switch event {
        case .delta(let text):
            deltas.append(text)
        case .completed(let result):
            completed = result
        case .started, .toolCallRequested, .toolCallCompleted, .failed:
            break
        }
    }

    #expect(deltas == ["he", "y"])
    #expect(completed?.message.content.text == "hey")
}

@Test func remoteBackendMapsOpenAIUsageAndFinishReason() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = """
    {
      "choices": [
        {
          "message": { "content": "done" },
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 7,
        "completion_tokens": 3,
        "total_tokens": 10
      }
    }
    """
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.openAI(apiKey: "token", baseURL: url),
        transport: RecordingTransport(responseBody: body)
    )
    let model = ModelDescriptor(id: "gpt-test", displayName: "GPT Test", family: .custom("openai"), backend: .remote, capabilities: [.chat], isRemote: true)
    let message = ChatMessage(role: .user, content: MessageContent(text: "hello"))

    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: [message]), model: model)) {
        if case .completed(let result) = event {
            completed = result
        }
    }

    #expect(completed?.message.content.text == "done")
    #expect(completed?.usage?.tokens.inputTokens == 7)
    #expect(completed?.usage?.tokens.outputTokens == 3)
    #expect(completed?.usage?.tokens.totalTokens == 10)
    #expect(completed?.finishReason == .stopped)
}

@Test func remoteBackendSkipsOpenAITerminalStreamChunkWithoutText() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = """
    data: {"choices":[{"delta":{"content":"he"}}]}

    data: {"choices":[{"delta":{"content":"y"}}]}

    data: {"choices":[{"finish_reason":"stop"}]}

    data: [DONE]

    """
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.openAI(apiKey: "token", baseURL: url),
        transport: RecordingTransport(responseBody: body)
    )
    let model = ModelDescriptor(
        id: "gpt-test",
        displayName: "GPT Test",
        family: .custom("openai"),
        backend: .remote,
        capabilities: [.chat],
        supportsStreaming: true,
        isRemote: true
    )
    let message = ChatMessage(role: .user, content: MessageContent(text: "hello"))

    var deltas: [String] = []
    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: [message]), model: model)) {
        switch event {
        case .delta(let text):
            deltas.append(text)
        case .completed(let result):
            completed = result
        case .started, .toolCallRequested, .toolCallCompleted, .failed:
            break
        }
    }

    #expect(deltas == ["he", "y"])
    #expect(completed?.message.content.text == "hey")
    #expect(completed?.finishReason == .stopped)
}

@Test func remoteBackendFailsOnProviderHTTPError() async throws {
    let message = RemoteProviderErrorMapper.message(
        statusCode: 500,
        headers: [:],
        body: Data(#"{"error":"nope"}"#.utf8),
        decoder: JSONDecoder()
    )

    #expect(message == "HTTP 500")
}

@Test func remoteBackendMapsOpenAIProviderErrorMessage() async throws {
    let message = RemoteProviderErrorMapper.message(
        statusCode: 401,
        headers: ["x-request-id": "req-openai"],
        body: Data(#"{"error":{"message":"invalid api key","type":"invalid_request_error","code":"invalid_api_key"}}"#.utf8),
        decoder: JSONDecoder()
    )

    #expect(message == "HTTP 401: invalid api key (type=invalid_request_error, code=invalid_api_key, request_id=req-openai)")
}

@Test func remoteBackendMapsAnthropicProviderErrorMessage() async throws {
    let message = RemoteProviderErrorMapper.message(
        statusCode: 429,
        headers: [:],
        body: Data(#"{"type":"error","error":{"type":"rate_limit_error","message":"rate limit exceeded"},"request_id":"req-anthropic"}"#.utf8),
        decoder: JSONDecoder()
    )

    #expect(message == "HTTP 429: rate limit exceeded (type=rate_limit_error, request_id=req-anthropic)")
}

@Test func anthropicChatFailsForToolRoleMessagesWithoutReference() async throws {
    let toolMessage = ChatMessage(role: .tool, content: MessageContent(text: "tool result"))

    do {
        _ = try AnthropicMessageMapper.map([toolMessage])
        Issue.record("Expected Anthropic mapping to reject tool messages without tool call metadata.")
    } catch {
        guard case .mappingFailed(let message) = error as? BackendError else {
            Issue.record("Expected mappingFailed error, got \(error)")
            return
        }
        #expect(message == "Anthropic tool messages require a tool call reference.")
    }
}

@Test func openAIResponsesChatFailsForToolRoleMessagesWithoutReference() async throws {
    let toolMessage = ChatMessage(role: .tool, content: MessageContent(text: "tool result"))

    do {
        _ = try OpenAIResponsesMessageMapper.map([toolMessage])
        Issue.record("Expected OpenAI Responses mapping to reject tool messages without tool call metadata.")
    } catch {
        guard case .mappingFailed(let message) = error as? BackendError else {
            Issue.record("Expected mappingFailed error, got \(error)")
            return
        }
        #expect(message == "OpenAI Responses tool messages require a tool call reference.")
    }
}

@Test func openAIResponsesBackendParsesToolCallResponse() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = #"{"output":[{"type":"function_call","call_id":"call_weather_1","name":"weather","arguments":"{\"city\":\"Paris\",\"days\":3}"}],"usage":{"input_tokens":5,"output_tokens":2,"total_tokens":7}}"#
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.openAIResponses(apiKey: "token", baseURL: url),
        transport: RecordingTransport(responseBody: body)
    )
    let model = RemoteModelDescriptors.openAIResponses(id: "gpt-responses-chat", supportsTools: true)
    let message = ChatMessage(role: .user, content: MessageContent(text: "weather"))

    var requested: [ToolInvocation] = []
    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: [message]), model: model)) {
        switch event {
        case .toolCallRequested(let invocation):
            requested.append(invocation)
        case .completed(let result):
            completed = result
        case .started, .delta, .toolCallCompleted, .failed:
            break
        }
    }

    #expect(requested.count == 1)
    #expect(requested.first?.id.rawValue == "call_weather_1")
    #expect(requested.first?.toolName == "weather")
    #expect(requested.first?.arguments["city"] == .string("Paris"))
    #expect(requested.first?.arguments["days"] == .integer(3))
    #expect(completed?.message.content.text == "")
    #expect(completed?.finishReason == .toolCall)
    #expect(completed?.usage?.tokens.totalTokens == 7)
}

@Test func anthropicBackendParsesToolUseResponse() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = #"{"content":[{"type":"tool_use","id":"toolu_weather_1","name":"weather","input":{"city":"Paris","metric":true}}],"stop_reason":"tool_use","usage":{"input_tokens":5,"output_tokens":1}}"#
    let backend = RemoteBackend(
        configuration: RemoteConfiguration.anthropic(apiKey: "token", baseURL: url),
        transport: RecordingTransport(responseBody: body)
    )
    let model = RemoteModelDescriptors.anthropicMessages(id: "claude-chat", supportsTools: true)
    let message = ChatMessage(role: .user, content: MessageContent(text: "weather"))

    var requested: [ToolInvocation] = []
    var completed: ChatResult?
    for try await event in backend.chat(BackendChatRequest(request: ChatRequest(messages: [message]), model: model)) {
        switch event {
        case .toolCallRequested(let invocation):
            requested.append(invocation)
        case .completed(let result):
            completed = result
        case .started, .delta, .toolCallCompleted, .failed:
            break
        }
    }

    #expect(requested.count == 1)
    #expect(requested.first?.id.rawValue == "toolu_weather_1")
    #expect(requested.first?.toolName == "weather")
    #expect(requested.first?.arguments["city"] == .string("Paris"))
    #expect(requested.first?.arguments["metric"] == .boolean(true))
    #expect(completed?.message.content.text == "")
    #expect(completed?.finishReason == .toolCall)
    #expect(completed?.usage?.tokens.totalTokens == 6)
}

@Test func remoteBackendFailsWhenNonStreamingResponseHasNoText() async throws {
    let mapper = RemoteResponseMapper(apiStyle: nil, decoder: JSONDecoder())

    do {
        _ = try mapper.decodeTextPayload(Data(#"{"choices":[{}]}"#.utf8))
        Issue.record("Expected remote backend to fail when response has no text field.")
    } catch {
        guard case .mappingFailed(let message) = error as? BackendError else {
            Issue.record("Expected mappingFailed error, got \(error)")
            return
        }
        #expect(message == "Remote response did not contain text.")
    }
}

@Test func remoteBackendFailsWhenStreamingDeltaHasNoText() async throws {
    let body = """
    data: {"choices":[{}]}

    data: [DONE]

    """
    let mapper = RemoteResponseMapper(apiStyle: nil, decoder: JSONDecoder())
    let events = try #require(mapper.streamEvents(from: Data(body.utf8)))

    do {
        _ = try mapper.collectStreamText(events) { _ in }
        Issue.record("Expected remote backend to fail when streaming delta has no text field.")
    } catch {
        guard case .mappingFailed(let message) = error as? BackendError else {
            Issue.record("Expected mappingFailed error, got \(error)")
            return
        }
        #expect(message == "Remote response did not contain text.")
    }
}

@Test func remoteBackendFailsWhenStreamContainsNoTextDeltas() async throws {
    let body = """
    data: [DONE]

    """
    let mapper = RemoteResponseMapper(apiStyle: nil, decoder: JSONDecoder())
    let events = try #require(mapper.streamEvents(from: Data(body.utf8)))

    do {
        _ = try mapper.collectStreamText(events) { _ in }
        Issue.record("Expected remote backend to fail when stream has no text deltas.")
    } catch {
        guard case .mappingFailed(let message) = error as? BackendError else {
            Issue.record("Expected mappingFailed error, got \(error)")
            return
        }
        #expect(message == "Remote stream did not contain text.")
    }
}

@Test func remoteBackendRequiresConfigurationAndTransportForAvailability() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let model = ModelDescriptor(id: "remote-model", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)

    let unavailable = await RemoteBackend(configuration: RemoteConfiguration(providerID: "test", baseURL: url)).availability(for: model)
    let available = await RemoteBackend(configuration: RemoteConfiguration(providerID: "test", baseURL: url), transport: RecordingTransport()).availability(for: model)

    #expect(unavailable.status != .available)
    #expect(available.status == .available)
}

private func requestBodyDictionary(_ request: HTTPRequest) throws -> [String: Any] {
    let bodyData = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
}

private struct OpenAIResponsesGenerationRequestBody: Decodable {
    let model: String
    let input: String
    let stream: Bool
    let text: TextBody?

    struct TextBody: Decodable, Equatable {
        let format: FormatBody
    }

    struct FormatBody: Decodable, Equatable {
        let type: String
        let name: String
        let schema: [String: ToolValue]
        let strict: Bool
    }
}

private func decodeOpenAIResponsesGenerationRequest(_ request: HTTPRequest) throws -> OpenAIResponsesGenerationRequestBody {
    let bodyData = try #require(request.body)
    return try JSONDecoder().decode(OpenAIResponsesGenerationRequestBody.self, from: bodyData)
}
