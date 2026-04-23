import Foundation
import LLMCore
import LLMNetworking
import LLMObservability
import LLMProtocols

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
                    let mapper = responseMapper
                    if let events = mapper.streamEvents(from: response.body), !events.isEmpty {
                        let payload = try mapper.collectStreamText(events) { continuation.yield(.delta($0)) }
                        continuation.yield(.completed(GenerationResult(
                            text: payload.text,
                            model: request.model,
                            usage: payload.usage,
                            finishReason: payload.finishReason
                        )))
                    } else {
                        let payload = try mapper.decodeTextPayload(response.body)
                        continuation.yield(.completed(GenerationResult(
                            text: payload.text,
                            model: request.model,
                            usage: payload.usage,
                            finishReason: payload.finishReason
                        )))
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
                    let payload: RemoteTextPayload
                    let mapper = responseMapper
                    if let events = mapper.streamEvents(from: response.body), !events.isEmpty {
                        payload = try mapper.collectStreamText(events) { continuation.yield(.delta($0)) }
                    } else {
                        payload = try mapper.decodeTextPayload(response.body)
                    }
                    let message = ChatMessage(role: .assistant, content: MessageContent(text: payload.text))
                    continuation.yield(.completed(ChatResult(
                        message: message,
                        model: request.model,
                        usage: payload.usage,
                        finishReason: payload.finishReason
                    )))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func makeGenerationRequest(_ request: BackendGenerationRequest) throws -> HTTPRequest {
        switch configuration?.apiStyle ?? .genericCompletionsAndChat {
        case .genericCompletionsAndChat:
            try makeRequest(
                path: configuration?.generationPath,
                body: RemoteCompletionRequest(model: request.model.id.rawValue, prompt: request.request.prompt, stream: request.model.supportsStreaming)
            )
        case .openAIChatCompletions:
            try makeRequest(
                path: configuration?.generationPath,
                body: OpenAIChatCompletionRequest(
                    model: request.model.id.rawValue,
                    messages: [
                        OpenAIChatMessage(role: MessageRole.user.rawValue, content: request.request.prompt)
                    ],
                    stream: request.model.supportsStreaming
                )
            )
        case .openAIResponses:
            try makeRequest(
                path: configuration?.generationPath,
                body: OpenAIResponsesRequest(
                    model: request.model.id.rawValue,
                    input: .text(request.request.prompt),
                    stream: request.model.supportsStreaming,
                    instructions: nil
                )
            )
        case .anthropicMessages(let defaultMaxTokens):
            try makeRequest(
                path: configuration?.generationPath,
                body: AnthropicMessagesRequest(
                    model: request.model.id.rawValue,
                    messages: [
                        AnthropicMessage(role: MessageRole.user.rawValue, content: request.request.prompt)
                    ],
                    maxTokens: defaultMaxTokens,
                    stream: request.model.supportsStreaming,
                    system: nil
                )
            )
        }
    }

    private func makeChatRequest(_ request: BackendChatRequest) throws -> HTTPRequest {
        switch configuration?.apiStyle ?? .genericCompletionsAndChat {
        case .genericCompletionsAndChat:
            let messages = request.request.messages.map {
                RemoteChatMessage(role: $0.role.rawValue, content: $0.content.text)
            }
            return try makeRequest(
                path: configuration?.chatPath,
                body: RemoteChatRequest(model: request.model.id.rawValue, messages: messages, stream: request.model.supportsStreaming)
            )
        case .openAIChatCompletions:
            let messages = request.request.messages.map {
                OpenAIChatMessage(role: $0.role.rawValue, content: $0.content.text)
            }
            return try makeRequest(
                path: configuration?.chatPath,
                body: OpenAIChatCompletionRequest(model: request.model.id.rawValue, messages: messages, stream: request.model.supportsStreaming)
            )
        case .openAIResponses:
            let mapping = try OpenAIResponsesMessageMapper.map(request.request.messages)
            return try makeRequest(
                path: configuration?.chatPath,
                body: OpenAIResponsesRequest(
                    model: request.model.id.rawValue,
                    input: .messages(mapping.messages),
                    stream: request.model.supportsStreaming,
                    instructions: mapping.instructions
                )
            )
        case .anthropicMessages(let defaultMaxTokens):
            let mapping = try AnthropicMessageMapper.map(request.request.messages)
            return try makeRequest(
                path: configuration?.chatPath,
                body: AnthropicMessagesRequest(
                    model: request.model.id.rawValue,
                    messages: mapping.messages,
                    maxTokens: defaultMaxTokens,
                    stream: request.model.supportsStreaming,
                    system: mapping.system
                )
            )
        }
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
            throw BackendError.providerFailed(RemoteProviderErrorMapper.message(
                statusCode: response.statusCode,
                headers: response.headers,
                body: response.body,
                decoder: decoder
            ))
        }
        return response
    }

    private var responseMapper: RemoteResponseMapper {
        RemoteResponseMapper(apiStyle: configuration?.apiStyle, decoder: decoder)
    }
}

public enum LLMBackendRemoteNamespace {}
