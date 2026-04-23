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
