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
}

struct OpenAIChatMessage: Encodable {
    let role: String
    let content: String
}

struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: OpenAIResponsesInput
    let stream: Bool
    let instructions: String?
}

enum OpenAIResponsesInput: Encodable {
    case text(String)
    case messages([OpenAIResponsesMessage])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .messages(let messages):
            try container.encode(messages)
        }
    }
}

struct OpenAIResponsesMessage: Encodable {
    let role: String
    let content: String
}

struct AnthropicMessagesRequest: Encodable {
    let model: String
    let messages: [AnthropicMessage]
    let maxTokens: Int
    let stream: Bool
    let system: String?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case stream
        case system
    }
}

struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}
