import Foundation

struct RemoteCompletionRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

struct RemoteChatRequest: Encodable {
    let model: String
    let messages: [RemoteChatMessage]
    let stream: Bool
}

struct RemoteChatMessage: Encodable {
    let role: String
    let content: String
}

struct OpenAIChatCompletionRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let stream: Bool
    let tools: [OpenAIChatTool]?
}

struct OpenAIChatMessage: Encodable {
    let role: String
    let content: String
    let toolCallID: String?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCallID = "tool_call_id"
    }
}

struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: OpenAIResponsesInput
    let stream: Bool
    let instructions: String?
    let tools: [OpenAIResponsesTool]?
}

enum OpenAIResponsesInput: Encodable {
    case text(String)
    case items([OpenAIResponsesInputItem])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .items(let items):
            try container.encode(items)
        }
    }
}

struct OpenAIResponsesInputItem: Encodable {
    let role: String?
    let content: String?
    let type: String?
    let callID: String?
    let output: String?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case type
        case callID = "call_id"
        case output
    }

    static func message(role: String, content: String) -> OpenAIResponsesInputItem {
        OpenAIResponsesInputItem(role: role, content: content, type: nil, callID: nil, output: nil)
    }

    static func functionCallOutput(callID: String, output: String) -> OpenAIResponsesInputItem {
        OpenAIResponsesInputItem(role: nil, content: nil, type: "function_call_output", callID: callID, output: output)
    }
}

struct AnthropicMessagesRequest: Encodable {
    let model: String
    let messages: [AnthropicMessage]
    let maxTokens: Int
    let stream: Bool
    let system: String?
    let tools: [AnthropicTool]?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case stream
        case system
        case tools
    }
}

struct AnthropicMessage: Encodable {
    let role: String
    let content: AnthropicMessageContent
}

enum AnthropicMessageContent: Encodable {
    case text(String)
    case blocks([AnthropicMessageContentBlock])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }
}

struct AnthropicMessageContentBlock: Encodable {
    let type: String
    let text: String?
    let toolUseID: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case toolUseID = "tool_use_id"
    }

    static func toolResult(toolUseID: String, content: String) -> AnthropicMessageContentBlock {
        AnthropicMessageContentBlock(type: "tool_result", text: content, toolUseID: toolUseID)
    }
}
