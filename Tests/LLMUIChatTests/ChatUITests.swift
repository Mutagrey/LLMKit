import LLMCore
import LLMProtocols
import LLMUIChat
import Testing

private struct StreamingChatService: ChatService {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.delta("hel"))
            continuation.yield(.delta("lo"))
            continuation.finish()
        }
    }
}

@MainActor
@Test func chatViewModelAppendsMessages() {
    let viewModel = ChatViewModel()

    viewModel.append(ChatMessage(role: .user, content: MessageContent(text: "hello")))

    #expect(viewModel.messages.count == 1)
}

@MainActor
@Test func chatViewModelSendsMessageThroughService() async {
    let viewModel = ChatViewModel(chatService: StreamingChatService())

    await viewModel.send("hi")

    #expect(viewModel.messages.map(\.role) == [.user, .assistant])
    #expect(viewModel.messages.last?.content.text == "hello")
    #expect(!viewModel.isStreaming)
}
