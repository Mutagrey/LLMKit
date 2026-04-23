import Foundation

public enum RemoteAPIStyle: Hashable, Sendable {
    case genericCompletionsAndChat
    case openAIChatCompletions
    case openAIResponses
    case anthropicMessages(defaultMaxTokens: Int)
}
