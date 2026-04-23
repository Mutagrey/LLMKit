import Foundation
import LLMCore
import LLMNetworking
import LLMObservability
import LLMProtocols

public struct RemoteProviderID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public struct RemoteConfiguration: Hashable, Sendable {
    public let providerID: RemoteProviderID
    public let baseURL: URL
    public let defaultHeaders: [String: String]
    public let generationPath: String
    public let chatPath: String

    public init(
        providerID: RemoteProviderID,
        baseURL: URL,
        defaultHeaders: [String: String] = [:],
        generationPath: String = "completions",
        chatPath: String = "chat/completions"
    ) {
        self.providerID = providerID
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.generationPath = generationPath
        self.chatPath = chatPath
    }
}

public struct RemoteBackend: ModelBackend {
    public let backendKind: BackendKind = .remote
    public let configuration: RemoteConfiguration?
    private let transport: (any HTTPTransport)?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: RemoteConfiguration? = nil,
        transport: (any HTTPTransport)? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.encoder = encoder
        self.decoder = decoder
    }

    public func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        guard configuration != nil, transport != nil else {
            return BackendAvailability(status: .unavailable(reason: "Remote backend is not configured."))
        }
        return .available
    }

    public func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.backend == backendKind && model.capabilities.contains(capability)
    }

    public func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle {
        guard await availability(for: descriptor).status == .available else {
            throw LLMError.unavailable
        }
        return LoadedModelHandle(id: descriptor.id, backend: descriptor.backend)
    }

    public func unloadModel(_ handle: LoadedModelHandle) async {}

    public func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.started(request.model))
                    let httpRequest = try makeGenerationRequest(request)
                    let response = try await send(httpRequest)
                    if let events = try streamEvents(from: response.body), !events.isEmpty {
                        let text = try collectStreamText(events) { continuation.yield(.delta($0)) }
                        continuation.yield(.completed(GenerationResult(text: text, model: request.model)))
                    } else {
                        let text = try decodeTextResponse(response.body)
                        continuation.yield(.completed(GenerationResult(text: text, model: request.model)))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.started(request.model))
                    let httpRequest = try makeChatRequest(request)
                    let response = try await send(httpRequest)
                    let text: String
                    if let events = try streamEvents(from: response.body), !events.isEmpty {
                        text = try collectStreamText(events) { continuation.yield(.delta($0)) }
                    } else {
                        text = try decodeTextResponse(response.body)
                    }
                    let message = ChatMessage(role: .assistant, content: MessageContent(text: text))
                    continuation.yield(.completed(ChatResult(message: message, model: request.model)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func makeGenerationRequest(_ request: BackendGenerationRequest) throws -> HTTPRequest {
        try makeRequest(
            path: configuration?.generationPath,
            body: RemoteCompletionRequest(model: request.model.id.rawValue, prompt: request.request.prompt, stream: request.model.supportsStreaming)
        )
    }

    private func makeChatRequest(_ request: BackendChatRequest) throws -> HTTPRequest {
        let messages = request.request.messages.map {
            RemoteChatMessage(role: $0.role.rawValue, content: $0.content.text)
        }
        return try makeRequest(
            path: configuration?.chatPath,
            body: RemoteChatRequest(model: request.model.id.rawValue, messages: messages, stream: request.model.supportsStreaming)
        )
    }

    private func makeRequest<T: Encodable>(path: String?, body: T) throws -> HTTPRequest {
        guard let configuration else {
            throw LLMError.unavailable
        }
        var headers = ["Content-Type": "application/json"]
        headers.merge(configuration.defaultHeaders) { _, new in new }
        let endpoint = path?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        return HTTPRequest(
            method: .post,
            url: configuration.baseURL.appendingPathComponent(endpoint),
            headers: headers,
            body: try encoder.encode(body)
        )
    }

    private func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let transport else {
            throw LLMError.unavailable
        }
        let response = try await transport.send(request)
        guard 200..<300 ~= response.statusCode else {
            throw BackendError.providerFailed("HTTP \(response.statusCode)")
        }
        return response
    }

    private func decodeTextResponse(_ data: Data) throws -> String {
        let body = try decoder.decode(RemoteTextResponse.self, from: data)
        guard let text = body.textValue else {
            throw BackendError.mappingFailed("Remote response did not contain text.")
        }
        return text
    }

    private func streamEvents(from data: Data) throws -> [SSEEvent]? {
        guard let text = String(data: data, encoding: .utf8), text.contains("data:") else {
            return nil
        }
        return SSEParser().parse(text)
    }

    private func collectStreamText(_ events: [SSEEvent], yield: (String) -> Void) throws -> String {
        var accumulator = StreamedTextAccumulator()
        for event in events where event.data != "[DONE]" {
            let delta = try decodeTextResponse(Data(event.data.utf8))
            accumulator.append(delta)
            yield(delta)
        }
        guard !accumulator.isEmpty else {
            throw BackendError.mappingFailed("Remote stream did not contain text.")
        }
        return accumulator.text
    }
}

public enum LLMBackendRemoteNamespace {}

private struct RemoteCompletionRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

private struct RemoteChatRequest: Encodable {
    let model: String
    let messages: [RemoteChatMessage]
    let stream: Bool
}

private struct RemoteChatMessage: Encodable {
    let role: String
    let content: String
}

private struct RemoteTextResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let text: String?
        let message: Message?
        let delta: Message?
    }

    let text: String?
    let choices: [Choice]?

    var textValue: String? {
        text ?? choices?.first?.text ?? choices?.first?.message?.content ?? choices?.first?.delta?.content
    }
}
