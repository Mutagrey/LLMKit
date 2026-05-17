import LLMCore

public protocol ChatService: Sendable {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error>
    func resetSession(_ sessionID: SessionID) async
}

public extension ChatService {
    func resetSession(_ sessionID: SessionID) async {}
}
