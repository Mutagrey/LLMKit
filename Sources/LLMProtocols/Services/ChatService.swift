import LLMCore

public protocol ChatService: Sendable {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error>
}
