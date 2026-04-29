import Foundation
import LLMCore

public struct ContextWindowDecision: Hashable, Sendable {
    public let messagesToCompress: [ChatMessage]
    public let recentMessages: [ChatMessage]

    public init(messagesToCompress: [ChatMessage], recentMessages: [ChatMessage]) {
        self.messagesToCompress = messagesToCompress
        self.recentMessages = recentMessages
    }

    public var requiresCompaction: Bool {
        !messagesToCompress.isEmpty
    }
}

public struct ContextWindowManager: Sendable {
    public let compactionRatio: Double
    public let preferredRecentMessageCount: Int
    private let estimator: SessionTokenEstimator

    public init(
        compactionRatio: Double = 0.75,
        preferredRecentMessageCount: Int = 6,
        estimator: SessionTokenEstimator = SessionTokenEstimator()
    ) {
        self.compactionRatio = compactionRatio
        self.preferredRecentMessageCount = preferredRecentMessageCount
        self.estimator = estimator
    }

    public func plan(for snapshot: SessionSnapshot, contextWindowTokens: Int?) -> ContextWindowDecision {
        guard let contextWindowTokens, contextWindowTokens > 0 else {
            return ContextWindowDecision(messagesToCompress: [], recentMessages: snapshot.messages)
        }

        let threshold = max(Int(Double(contextWindowTokens) * compactionRatio), 1)
        guard estimator.estimateTokens(summary: snapshot.summary, messages: snapshot.messages) > threshold else {
            return ContextWindowDecision(messagesToCompress: [], recentMessages: snapshot.messages)
        }

        var retainedCount = min(max(2, preferredRecentMessageCount), snapshot.messages.count)
        while retainedCount > 2 {
            let recentMessages = Array(snapshot.messages.suffix(retainedCount))
            if estimator.estimateTokens(summary: snapshot.summary, messages: recentMessages) <= threshold {
                break
            }
            retainedCount -= 1
        }

        guard retainedCount < snapshot.messages.count else {
            return ContextWindowDecision(messagesToCompress: [], recentMessages: snapshot.messages)
        }

        return ContextWindowDecision(
            messagesToCompress: Array(snapshot.messages.dropLast(retainedCount)),
            recentMessages: Array(snapshot.messages.suffix(retainedCount))
        )
    }
}
