import Foundation
import LLMCore

struct AnthropicTextResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    let content: [ContentBlock]
    let stopReason: String?
    let usage: AnthropicUsage?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
        case usage
    }

    var textValue: String? {
        let text = content.compactMap(\.text).joined()
        return text.isEmpty ? nil : text
    }
}

struct AnthropicStreamEvent: Decodable {
    struct Delta: Decodable {
        let type: String?
        let text: String?
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case stopReason = "stop_reason"
        }
    }

    struct Message: Decodable {
        let usage: AnthropicUsage?
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case usage
            case stopReason = "stop_reason"
        }
    }

    struct ErrorBody: Decodable {
        let message: String?
    }

    let type: String
    let delta: Delta?
    let message: Message?
    let usage: AnthropicUsage?
    let error: ErrorBody?
}

struct AnthropicUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    var metrics: UsageMetrics {
        let total: Int?
        if let inputTokens, let outputTokens {
            total = inputTokens + outputTokens
        } else {
            total = nil
        }
        return UsageMetrics(tokens: TokenUsage(inputTokens: inputTokens, outputTokens: outputTokens, totalTokens: total))
    }
}

enum AnthropicFinishReasonMapper {
    static func map(_ value: String) -> StreamFinishReason {
        switch value {
        case "end_turn", "stop_sequence":
            return .stopped
        case "max_tokens":
            return .lengthLimit
        case "tool_use":
            return .toolCall
        default:
            return .completed
        }
    }
}
