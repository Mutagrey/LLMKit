import Foundation
import LLMCore

struct OpenAIResponsesTextResponse: Decodable {
    struct OutputItem: Decodable {
        struct ContentPart: Decodable {
            let type: String?
            let text: String?
        }

        let type: String?
        let id: String?
        let callID: String?
        let name: String?
        let arguments: String?
        let content: [ContentPart]?

        enum CodingKeys: String, CodingKey {
            case type
            case id
            case callID = "call_id"
            case name
            case arguments
            case content
        }
    }

    let output: [OutputItem]?
    let outputText: String?
    let usage: OpenAIResponsesUsage?

    enum CodingKeys: String, CodingKey {
        case output
        case outputText = "output_text"
        case usage
    }

    var textValue: String? {
        if let outputText, !outputText.isEmpty {
            return outputText
        }
        var textParts: [String] = []
        for item in output ?? [] where item.type == nil || item.type == "message" {
            for part in item.content ?? [] where part.type == nil || part.type == "output_text" {
                if let text = part.text {
                    textParts.append(text)
                }
            }
        }
        let text = textParts.joined()
        return text.isEmpty ? nil : text
    }

    var toolInvocations: [ToolInvocation] {
        (output ?? []).compactMap { item in
            guard item.type == "function_call" else {
                return nil
            }
            return try? RemoteToolInvocationMapper.invocation(
                callID: item.callID,
                fallbackID: item.id,
                toolName: item.name,
                argumentsJSON: item.arguments
            )
        }
    }
}

struct OpenAIResponsesStreamEvent: Decodable {
    struct Item: Decodable {
        let id: String?
        let type: String?
        let callID: String?
        let name: String?
        let arguments: String?

        enum CodingKeys: String, CodingKey {
            case id
            case type
            case callID = "call_id"
            case name
            case arguments
        }
    }

    struct Response: Decodable {
        struct ErrorBody: Decodable {
            let code: String?
            let message: String?
        }

        struct IncompleteDetails: Decodable {
            let reason: String?
        }

        let usage: OpenAIResponsesUsage?
        let error: ErrorBody?
        let incompleteDetails: IncompleteDetails?

        enum CodingKeys: String, CodingKey {
            case usage
            case error
            case incompleteDetails = "incomplete_details"
        }
    }

    struct ErrorBody: Decodable {
        let code: String?
        let message: String?
    }

    let type: String
    let delta: String?
    let text: String?
    let item: Item?
    let callID: String?
    let name: String?
    let arguments: String?
    let response: Response?
    let error: ErrorBody?

    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case text
        case item
        case callID = "call_id"
        case name
        case arguments
        case response
        case error
    }
}

struct OpenAIResponsesUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }

    var metrics: UsageMetrics {
        UsageMetrics(tokens: TokenUsage(inputTokens: inputTokens, outputTokens: outputTokens, totalTokens: totalTokens))
    }
}

enum OpenAIResponsesFinishReasonMapper {
    static func mapIncompleteReason(_ value: String) -> StreamFinishReason {
        switch value {
        case "max_output_tokens", "max_tokens":
            return .lengthLimit
        default:
            return .completed
        }
    }
}
