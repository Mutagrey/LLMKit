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
            finishReason: body.finishReasonValue.map(RemoteFinishReasonMapper.map) ?? .completed
        )
    }

    func streamEvents(from data: Data) -> [SSEEvent]? {
        guard let text = String(data: data, encoding: .utf8), text.contains("data:") else {
            return nil
        }
        return SSEParser().parse(text)
    }

    func collectStreamText(_ events: [SSEEvent], yield: (String) -> Void) throws -> RemoteTextPayload {
        if case .anthropicMessages = apiStyle {
            return try collectAnthropicStreamText(events, yield: yield)
        }
        if case .openAIResponses = apiStyle {
            return try collectOpenAIResponsesStreamText(events, yield: yield)
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

    private func decodeOpenAIResponsesTextPayload(_ data: Data) throws -> RemoteTextPayload {
        let body = try decoder.decode(OpenAIResponsesTextResponse.self, from: data)
        guard let text = body.textValue else {
            throw BackendError.mappingFailed("Remote response did not contain text.")
        }
        return RemoteTextPayload(text: text, usage: body.usage?.metrics, finishReason: .completed)
    }

    private func collectOpenAIResponsesStreamText(_ events: [SSEEvent], yield: (String) -> Void) throws -> RemoteTextPayload {
        var accumulator = StreamedTextAccumulator()
        var usage: UsageMetrics?
        var finishReason: StreamFinishReason = .completed

        for event in events where event.data != "[DONE]" {
            let body = try decoder.decode(OpenAIResponsesStreamEvent.self, from: Data(event.data.utf8))
            switch body.type {
            case "response.output_text.delta":
                guard let delta = body.delta else { continue }
                accumulator.append(delta)
                yield(delta)
            case "response.output_text.done":
                if accumulator.isEmpty, let text = body.text {
                    accumulator.append(text)
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
                continue
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

        for event in events where event.data != "[DONE]" {
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
