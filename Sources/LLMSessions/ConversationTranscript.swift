import LLMCore

public struct ConversationTranscript: Hashable, Sendable {
    public let messages: [ChatMessage]

    public init(messages: [ChatMessage] = []) {
        self.messages = messages
    }

    public func appending(_ message: ChatMessage) -> ConversationTranscript {
        ConversationTranscript(messages: messages + [message])
    }
}

public struct TranscriptWindow: Hashable, Sendable {
    public let messages: [ChatMessage]

    public init(messages: [ChatMessage]) {
        self.messages = messages
    }
}

public struct SessionTruncationPolicy: Hashable, Sendable {
    public let maxMessages: Int

    public init(maxMessages: Int) {
        self.maxMessages = maxMessages
    }

    public func apply(to transcript: ConversationTranscript) -> TranscriptWindow {
        TranscriptWindow(messages: Array(transcript.messages.suffix(maxMessages)))
    }
}
