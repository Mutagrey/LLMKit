import Foundation
import LLMCore

struct RemoteTextPayload {
    let text: String
    let usage: UsageMetrics?
    let finishReason: StreamFinishReason
    let toolInvocations: [ToolInvocation]
}

struct RemoteTextResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let text: String?
        let message: Message?
        let delta: Message?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case text
            case message
            case delta
            case finishReason = "finish_reason"
        }
    }

    let text: String?
    let choices: [Choice]?
    let usage: RemoteUsage?

    var textValue: String? {
        text ?? choices?.first?.text ?? choices?.first?.message?.content ?? choices?.first?.delta?.content
    }

    var finishReasonValue: String? {
        choices?.compactMap(\.finishReason).first
    }

    var isTerminalChunk: Bool {
        finishReasonValue != nil || usage != nil
    }
}

struct RemoteUsage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }

    var metrics: UsageMetrics {
        UsageMetrics(tokens: TokenUsage(inputTokens: promptTokens, outputTokens: completionTokens, totalTokens: totalTokens))
    }
}

enum RemoteFinishReasonMapper {
    static func map(_ value: String) -> StreamFinishReason {
        switch value {
        case "stop":
            return .stopped
        case "length":
            return .lengthLimit
        case "tool_calls", "function_call":
            return .toolCall
        default:
            return .completed
        }
    }
}

enum RemoteUsageMerger {
    static func merge(base: UsageMetrics?, output other: UsageMetrics) -> UsageMetrics {
        guard let base else {
            return other
        }
        let input = base.tokens.inputTokens
        let output = other.tokens.outputTokens ?? base.tokens.outputTokens
        let total: Int?
        if let input, let output {
            total = input + output
        } else {
            total = base.tokens.totalTokens ?? other.tokens.totalTokens
        }
        return UsageMetrics(tokens: TokenUsage(inputTokens: input, outputTokens: output, totalTokens: total), latencyMilliseconds: base.latencyMilliseconds)
    }
}
