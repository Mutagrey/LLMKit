import Foundation
import LLMCore

struct AnthropicTextResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: ToolValue]?
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

    var toolInvocations: [ToolInvocation] {
        content.compactMap { block in
            guard block.type == "tool_use" else {
                return nil
            }
            return RemoteToolInvocationMapper.invocation(
                callID: block.id,
                fallbackID: nil,
                toolName: block.name,
                inputObject: block.input
            )
        }
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

    struct ContentBlock: Decodable {
        let type: String?
        let id: String?
        let name: String?
        let input: [String: ToolValue]?
    }

    let type: String
    let delta: Delta?
    let message: Message?
    let usage: AnthropicUsage?
    let error: ErrorBody?
    let contentBlock: ContentBlock?

    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case message
        case usage
        case error
        case contentBlock = "content_block"
    }
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
