import LLMCore
import LLMUIChat
import Testing

@MainActor
@Test func chatViewModelAppendsMessages() {
    let viewModel = ChatViewModel()

    viewModel.append(ChatMessage(role: .user, content: MessageContent(text: "hello")))

    #expect(viewModel.messages.count == 1)
}
