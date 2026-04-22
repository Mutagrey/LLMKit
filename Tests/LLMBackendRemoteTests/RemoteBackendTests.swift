import Foundation
import LLMBackendRemote
import LLMCore
import LLMNetworking
import LLMProtocols
import Testing

private actor RecordingTransport: HTTPTransport {
    private(set) var requests: [HTTPRequest] = []
    private let responseBody: String
    private let statusCode: Int

    init(responseBody: String = #"{"choices":[{"text":"remote hello"}]}"#, statusCode: Int = 200) {
        self.responseBody = responseBody
        self.statusCode = statusCode
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let body = responseBody.data(using: .utf8) ?? Data()
        return HTTPResponse(statusCode: statusCode, body: body)
    }
}

@Test func remoteConfigurationStoresProviderID() throws {
    let url = try #require(URL(string: "https://example.com"))
    let configuration = RemoteConfiguration(providerID: "test", baseURL: url)

    #expect(configuration.providerID.rawValue == "test")
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

@Test func remoteBackendFailsOnProviderHTTPError() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let backend = RemoteBackend(
        configuration: RemoteConfiguration(providerID: "test", baseURL: url),
        transport: RecordingTransport(responseBody: #"{"error":"nope"}"#, statusCode: 500)
    )
    let model = ModelDescriptor(id: "remote-model", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {}
        Issue.record("Expected remote backend to fail on non-2xx provider response.")
    } catch {
        #expect(error as? BackendError == .providerFailed("HTTP 500"))
    }
}

@Test func remoteBackendFailsWhenNonStreamingResponseHasNoText() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let backend = RemoteBackend(
        configuration: RemoteConfiguration(providerID: "test", baseURL: url),
        transport: RecordingTransport(responseBody: #"{"choices":[{}]}"#)
    )
    let model = ModelDescriptor(id: "remote-model", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {}
        Issue.record("Expected remote backend to fail when response has no text field.")
    } catch {
        #expect(error as? BackendError == .mappingFailed("Remote response did not contain text."))
    }
}

@Test func remoteBackendFailsWhenStreamingDeltaHasNoText() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let body = """
    data: {"choices":[{}]}

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

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: model)) {}
        Issue.record("Expected remote backend to fail when streaming delta has no text field.")
    } catch {
        #expect(error as? BackendError == .mappingFailed("Remote response did not contain text."))
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
