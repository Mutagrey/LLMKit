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
                    if let events = streamEvents(from: response.body), !events.isEmpty {
                        let payload = try collectStreamText(events) { continuation.yield(.delta($0)) }
                        continuation.yield(.completed(GenerationResult(
                            text: payload.text,
                            model: request.model,
                            usage: payload.usage,
                            finishReason: payload.finishReason
                        )))
                    } else {
                        let payload = try decodeTextPayload(response.body)
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
                    if let events = streamEvents(from: response.body), !events.isEmpty {
                        payload = try collectStreamText(events) { continuation.yield(.delta($0)) }
                    } else {
                        payload = try decodeTextPayload(response.body)
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

    private func decodeTextPayload(_ data: Data) throws -> RemoteTextPayload {
        if case .anthropicMessages = configuration?.apiStyle {
            return try decodeAnthropicTextPayload(data)
        }
        let body = try decoder.decode(RemoteTextResponse.self, from: data)
        guard let text = body.textValue else {
            throw BackendError.mappingFailed("Remote response did not contain text.")
        }
        return RemoteTextPayload(
            text: text,
            usage: body.usage?.metrics,
            finishReason: body.finishReasonValue.map(RemoteFinishReasonMapper.map) ?? .completed
        )
    }

    private func streamEvents(from data: Data) -> [SSEEvent]? {
        guard let text = String(data: data, encoding: .utf8), text.contains("data:") else {
            return nil
        }
        return SSEParser().parse(text)
    }

    private func collectStreamText(_ events: [SSEEvent], yield: (String) -> Void) throws -> RemoteTextPayload {
        if case .anthropicMessages = configuration?.apiStyle {
            return try collectAnthropicStreamText(events, yield: yield)
        }
        var accumulator = StreamedTextAccumulator()
        var usage: UsageMetrics?
        var finishReason: StreamFinishReason = .completed
        for event in events where event.data != "[DONE]" {
            let body = try decoder.decode(RemoteTextResponse.self, from: Data(event.data.utf8))
            if let delta = body.textValue {
                accumulator.append(delta)
                yield(delta)
            } else if !body.isTerminalChunk {
                throw BackendError.mappingFailed("Remote response did not contain text.")
            }
            if let bodyUsage = body.usage?.metrics {
                usage = bodyUsage
            }
            if let bodyFinishReason = body.finishReasonValue {
                finishReason = RemoteFinishReasonMapper.map(bodyFinishReason)
            }
        }
        guard !accumulator.isEmpty else {
            throw BackendError.mappingFailed("Remote stream did not contain text.")
        }
        return RemoteTextPayload(text: accumulator.text, usage: usage, finishReason: finishReason)
    }

    private func decodeAnthropicTextPayload(_ data: Data) throws -> RemoteTextPayload {
        let body = try decoder.decode(AnthropicTextResponse.self, from: data)
        guard let text = body.textValue else {
            throw BackendError.mappingFailed("Remote response did not contain text.")
        }
        return RemoteTextPayload(
            text: text,
            usage: body.usage?.metrics,
            finishReason: body.stopReason.map(AnthropicFinishReasonMapper.map) ?? .completed
        )
    }

    private func collectAnthropicStreamText(_ events: [SSEEvent], yield: (String) -> Void) throws -> RemoteTextPayload {
        var accumulator = StreamedTextAccumulator()
        var usage: UsageMetrics?
        var finishReason: StreamFinishReason = .completed

        for event in events {
            let body = try decoder.decode(AnthropicStreamEvent.self, from: Data(event.data.utf8))
            switch body.type {
            case "content_block_delta":
                guard body.delta?.type == "text_delta", let delta = body.delta?.text else {
                    continue
                }
                accumulator.append(delta)
                yield(delta)
            case "message_start":
                if let bodyUsage = body.message?.usage?.metrics {
                    usage = bodyUsage
                }
            case "message_delta":
                if let outputUsage = body.usage?.metrics {
                    usage = RemoteUsageMerger.merge(base: usage, output: outputUsage)
                }
                if let stopReason = body.delta?.stopReason {
                    finishReason = AnthropicFinishReasonMapper.map(stopReason)
                }
            case "error":
                throw BackendError.providerFailed(body.error?.message ?? "Anthropic stream error")
            default:
                continue
            }
        }

        guard !accumulator.isEmpty else {
            throw BackendError.mappingFailed("Remote stream did not contain text.")
        }
        return RemoteTextPayload(text: accumulator.text, usage: usage, finishReason: finishReason)
    }

}

public enum LLMBackendRemoteNamespace {}
