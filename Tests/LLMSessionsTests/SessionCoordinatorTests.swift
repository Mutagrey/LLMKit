import LLMCore
import LLMSessions
import Testing

@Test func sessionCoordinatorAppendsMessages() async throws {
    let coordinator = SessionCoordinator()
    let session = await coordinator.createSession(title: "Test")
    let message = ChatMessage(role: .user, content: MessageContent(text: "Hello"))

    let updated = try await coordinator.append(message, to: session.id)

    #expect(updated.messages.count == 1)
    #expect(updated.messages.first?.content.text == "Hello")
}
