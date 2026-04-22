import Foundation
import LLMBackendRemote
import LLMCore
import LLMNetworking
import LLMProtocols
import Testing

private actor RecordingTransport: HTTPTransport {
    private(set) var requests: [HTTPRequest] = []
    private let responseBody: String

    init(responseBody: String = #"{"choices":[{"text":"remote hello"}]}"#) {
        self.responseBody = responseBody
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let body = responseBody.data(using: .utf8) ?? Data()
        return HTTPResponse(statusCode: 200, body: body)
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

@Test func remoteBackendRequiresConfigurationAndTransportForAvailability() async throws {
    let url = try #require(URL(string: "https://example.com/v1"))
    let model = ModelDescriptor(id: "remote-model", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)

    let unavailable = await RemoteBackend(configuration: RemoteConfiguration(providerID: "test", baseURL: url)).availability(for: model)
    let available = await RemoteBackend(configuration: RemoteConfiguration(providerID: "test", baseURL: url), transport: RecordingTransport()).availability(for: model)

    #expect(unavailable.status != .available)
    #expect(available.status == .available)
}
