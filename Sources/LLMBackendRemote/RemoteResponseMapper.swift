import Foundation
import LLMCore
import LLMNetworking

struct RemoteResponseMapper {
    let apiStyle: RemoteAPIStyle?
    let decoder: JSONDecoder

    func decodeTextPayload(_ data: Data) throws -> RemoteTextPayload {
        if case .anthropicMessages = apiStyle {
            return try decodeAnthropicTextPayload(data)
        }
        if case .openAIResponses = apiStyle {
            return try decodeOpenAIResponsesTextPayload(data)
        }
        let body = try decoder.decode(RemoteTextResponse.self, from: data)
        guard let text = body.textValue else {
            throw BackendError.mappingFailed("Remote response did not contain text.")
        }
        return RemoteTextPayload(
            text: text,
            usage: body.usage?.metrics,
            finishReason: body.finishReasonValue.map(RemoteFinishReasonMapper.map) ?? .completed,
            toolInvocations: []
        )
    }

    func streamEvents(from data: Data) -> [SSEEvent]? {
        guard let text = String(data: data, encoding: .utf8), text.contains("data:") else {
            return nil
        }
        return SSEParser().parse(text)
    }

    func collectStreamText(_ events: [SSEEvent], yield: (String) -> Void) throws -> RemoteTextPayload {
        var accumulator = makeStreamAccumulator()
        for event in events {
            try accumulator.consume(event, yield: yield)
        }
        return try accumulator.finish()
    }

    func makeStreamAccumulator() -> RemoteStreamAccumulator {
        RemoteStreamAccumulator(apiStyle: apiStyle, decoder: decoder)
    }

    private func decodeOpenAIResponsesTextPayload(_ data: Data) throws -> RemoteTextPayload {
        let body = try decoder.decode(OpenAIResponsesTextResponse.self, from: data)
        guard let text = body.textValue ?? (body.toolInvocations.isEmpty ? nil : "") else {
            throw BackendError.mappingFailed("Remote response did not contain text.")
        }
        return RemoteTextPayload(
            text: text,
            usage: body.usage?.metrics,
            finishReason: body.toolInvocations.isEmpty ? .completed : .toolCall,
            toolInvocations: body.toolInvocations
        )
    }

    private func decodeAnthropicTextPayload(_ data: Data) throws -> RemoteTextPayload {
        let body = try decoder.decode(AnthropicTextResponse.self, from: data)
        guard let text = body.textValue ?? (body.toolInvocations.isEmpty ? nil : "") else {
            throw BackendError.mappingFailed("Remote response did not contain text.")
        }
        return RemoteTextPayload(
            text: text,
            usage: body.usage?.metrics,
            finishReason: body.stopReason.map(AnthropicFinishReasonMapper.map) ?? (body.toolInvocations.isEmpty ? .completed : .toolCall),
            toolInvocations: body.toolInvocations
        )
    }
}

struct RemoteStreamAccumulator {
    let apiStyle: RemoteAPIStyle?
    let decoder: JSONDecoder
    private var accumulator = StreamedTextAccumulator()
    private var usage: UsageMetrics?
    private var finishReason: StreamFinishReason = .completed
    private var toolInvocations: [ToolInvocation] = []

    init(apiStyle: RemoteAPIStyle?, decoder: JSONDecoder) {
        self.apiStyle = apiStyle
        self.decoder = decoder
    }

    mutating func consume(_ event: SSEEvent, yield: (String) -> Void) throws {
        guard event.data != "[DONE]" else {
            return
        }
        if case .anthropicMessages = apiStyle {
            try consumeAnthropic(event, yield: yield)
        } else if case .openAIResponses = apiStyle {
            try consumeOpenAIResponses(event, yield: yield)
        } else {
            try consumeGeneric(event, yield: yield)
        }
    }

    func finish() throws -> RemoteTextPayload {
        guard !accumulator.isEmpty || !toolInvocations.isEmpty else {
            throw BackendError.mappingFailed("Remote stream did not contain text.")
        }
        return RemoteTextPayload(
            text: accumulator.text,
            usage: usage,
            finishReason: finishReason,
            toolInvocations: toolInvocations
        )
    }

    private mutating func consumeGeneric(_ event: SSEEvent, yield: (String) -> Void) throws {
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

    private mutating func consumeOpenAIResponses(_ event: SSEEvent, yield: (String) -> Void) throws {
        let body = try decoder.decode(OpenAIResponsesStreamEvent.self, from: Data(event.data.utf8))
        switch body.type {
        case "response.output_text.delta":
            guard let delta = body.delta else { return }
            accumulator.append(delta)
            yield(delta)
        case "response.output_text.done":
            if accumulator.isEmpty, let text = body.text {
                accumulator.append(text)
            }
        case "response.output_item.done":
            guard body.item?.type == "function_call" else {
                return
            }
            if let invocation = try RemoteToolInvocationMapper.invocation(
                callID: body.item?.callID,
                fallbackID: body.item?.id,
                toolName: body.item?.name,
                argumentsJSON: body.item?.arguments
            ) {
                toolInvocations.append(invocation)
                finishReason = .toolCall
            }
        case "response.function_call_arguments.done":
            if let invocation = try RemoteToolInvocationMapper.invocation(
                callID: body.callID,
                fallbackID: nil,
                toolName: body.name,
                argumentsJSON: body.arguments
            ) {
                toolInvocations.append(invocation)
                finishReason = .toolCall
            }
        case "response.completed":
            if let bodyUsage = body.response?.usage?.metrics {
                usage = bodyUsage
            }
        case "response.incomplete":
            if let reason = body.response?.incompleteDetails?.reason {
                finishReason = OpenAIResponsesFinishReasonMapper.mapIncompleteReason(reason)
            }
            if let bodyUsage = body.response?.usage?.metrics {
                usage = bodyUsage
            }
        case "response.failed":
            let message = body.response?.error?.message ?? "OpenAI Responses stream failed."
            throw BackendError.providerFailed(message)
        case "error":
            throw BackendError.providerFailed(body.error?.message ?? "OpenAI Responses stream error.")
        default:
            return
        }
    }

    private mutating func consumeAnthropic(_ event: SSEEvent, yield: (String) -> Void) throws {
        let body = try decoder.decode(AnthropicStreamEvent.self, from: Data(event.data.utf8))
        switch body.type {
        case "content_block_start":
            guard body.contentBlock?.type == "tool_use" else {
                return
            }
            if let invocation = RemoteToolInvocationMapper.invocation(
                callID: body.contentBlock?.id,
                fallbackID: nil,
                toolName: body.contentBlock?.name,
                inputObject: body.contentBlock?.input
            ) {
                toolInvocations.append(invocation)
                finishReason = .toolCall
            }
        case "content_block_delta":
            guard body.delta?.type == "text_delta", let delta = body.delta?.text else {
                return
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
            return
        }
    }
}
