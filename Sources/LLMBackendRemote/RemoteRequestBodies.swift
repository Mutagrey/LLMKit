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
