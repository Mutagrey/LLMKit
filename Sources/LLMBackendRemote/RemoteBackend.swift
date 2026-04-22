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
                    let response = try await sendGeneration(request)
                    continuation.yield(.completed(GenerationResult(text: response, model: request.model)))
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
                    let response = try await sendChat(request)
                    let message = ChatMessage(role: .assistant, content: MessageContent(text: response))
                    continuation.yield(.completed(ChatResult(message: message, model: request.model)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func sendGeneration(_ request: BackendGenerationRequest) async throws -> String {
        let httpRequest = try makeRequest(
            path: configuration?.generationPath,
            body: RemoteCompletionRequest(model: request.model.id.rawValue, prompt: request.request.prompt, stream: false)
        )
        return try await send(httpRequest)
    }

    private func sendChat(_ request: BackendChatRequest) async throws -> String {
        let messages = request.request.messages.map {
            RemoteChatMessage(role: $0.role.rawValue, content: $0.content.text)
        }
        let httpRequest = try makeRequest(
            path: configuration?.chatPath,
            body: RemoteChatRequest(model: request.model.id.rawValue, messages: messages, stream: false)
        )
        return try await send(httpRequest)
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

    private func send(_ request: HTTPRequest) async throws -> String {
        guard let transport else {
            throw LLMError.unavailable
        }
        let response = try await transport.send(request)
        guard 200..<300 ~= response.statusCode else {
            throw BackendError.providerFailed("HTTP \(response.statusCode)")
        }
        let body = try decoder.decode(RemoteTextResponse.self, from: response.body)
        guard let text = body.textValue else {
            throw BackendError.mappingFailed("Remote response did not contain text.")
        }
        return text
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
    }

    let text: String?
    let choices: [Choice]?

    var textValue: String? {
        text ?? choices?.first?.text ?? choices?.first?.message?.content
    }
}
