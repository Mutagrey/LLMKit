import LLMCore

public struct SessionTokenEstimator: Sendable {
    public init() {}

    public func estimateTokens(in text: String) -> Int {
        max(1, (text.utf8.count + 3) / 4)
    }

    public func estimateTokens(in message: ChatMessage) -> Int {
        estimateTokens(in: message.content.text)
    }

    public func estimateTokens(summary: SessionSummary?, messages: [ChatMessage]) -> Int {
        let summaryTokens = summary.map { estimateTokens(in: $0.text) } ?? 0
        return summaryTokens + messages.reduce(0) { $0 + estimateTokens(in: $1) }
    }
}
