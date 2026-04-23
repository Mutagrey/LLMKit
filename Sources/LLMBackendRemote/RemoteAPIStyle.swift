import Foundation

public enum RemoteAPIStyle: Hashable, Sendable {
    case genericCompletionsAndChat
    case openAIChatCompletions
    case anthropicMessages(defaultMaxTokens: Int)
}
