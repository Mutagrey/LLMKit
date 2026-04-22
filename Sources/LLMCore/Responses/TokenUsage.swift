import Foundation

public struct TokenUsage: Hashable, Codable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?

    public init(inputTokens: Int? = nil, outputTokens: Int? = nil, totalTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}

public struct UsageMetrics: Hashable, Codable, Sendable {
    public let tokens: TokenUsage
    public let latencyMilliseconds: Double?

    public init(tokens: TokenUsage = TokenUsage(), latencyMilliseconds: Double? = nil) {
        self.tokens = tokens
        self.latencyMilliseconds = latencyMilliseconds
    }
}
