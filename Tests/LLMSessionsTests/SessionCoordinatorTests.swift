import LLMCore
import LLMProtocols
import LLMSessions
import Testing

private actor InMemorySessionStore: SessionStore {
    private var snapshots: [SessionID: SessionSnapshot] = [:]
    private(set) var savedSnapshots: [SessionSnapshot] = []
    private(set) var loadedIDs: [SessionID] = []

    init(snapshots: [SessionSnapshot] = []) {
        self.snapshots = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
    }

    func loadSession(id: SessionID) async throws -> SessionSnapshot? {
        loadedIDs.append(id)
        return snapshots[id]
    }

    func saveSession(_ snapshot: SessionSnapshot) async throws {
        snapshots[snapshot.id] = snapshot
        savedSnapshots.append(snapshot)
    }

    func deleteSession(id: SessionID) async throws {
        snapshots[id] = nil
    }
}

@Test func sessionCoordinatorAppendsMessages() async throws {
    let coordinator = SessionCoordinator()
    let session = await coordinator.createSession(title: "Test")
    let message = ChatMessage(role: .user, content: MessageContent(text: "Hello"))

    let updated = try await coordinator.append(message, to: session.id)

    #expect(updated.messages.count == 1)
    #expect(updated.messages.first?.content.text == "Hello")
}

@Test func conversationTranscriptAppendingReturnsNewTranscript() {
    let original = ConversationTranscript()
    let message = ChatMessage(role: .user, content: MessageContent(text: "Hello"))

    let updated = original.appending(message)

    #expect(original.messages.isEmpty)
    #expect(updated.messages.map(\.content.text) == ["Hello"])
}

@Test func sessionTruncationPolicyKeepsMostRecentMessages() {
    let transcript = ConversationTranscript(messages: [
        ChatMessage(role: .user, content: MessageContent(text: "one")),
        ChatMessage(role: .assistant, content: MessageContent(text: "two")),
        ChatMessage(role: .user, content: MessageContent(text: "three"))
    ])

    let window = SessionTruncationPolicy(maxMessages: 2).apply(to: transcript)

    #expect(window.messages.map(\.content.text) == ["two", "three"])
}

@Test func sessionTruncationPolicyAllowsEmptyWindow() {
    let transcript = ConversationTranscript(messages: [
        ChatMessage(role: .user, content: MessageContent(text: "one")),
        ChatMessage(role: .assistant, content: MessageContent(text: "two"))
    ])

    let window = SessionTruncationPolicy(maxMessages: 0).apply(to: transcript)

    #expect(window.messages.isEmpty)
}

@Test func sessionCoordinatorLoadsSnapshotFromStoreBeforeAppending() async throws {
    let sessionID: SessionID = "stored-session"
    let existing = ChatMessage(role: .user, content: MessageContent(text: "Existing"))
    let stored = SessionSnapshot(
        id: sessionID,
        descriptor: SessionDescriptor(id: sessionID, title: "Stored"),
        messages: [existing]
    )
    let store = InMemorySessionStore(snapshots: [stored])
    let coordinator = SessionCoordinator(store: store)
    let appended = ChatMessage(role: .assistant, content: MessageContent(text: "Reply"))

    let updated = try await coordinator.append(appended, to: sessionID)

    #expect(updated.messages.map(\.content.text) == ["Existing", "Reply"])
    #expect(await store.savedSnapshots.last?.messages.map(\.content.text) == ["Existing", "Reply"])
}

@Test func sessionCoordinatorCachesLoadedSnapshot() async throws {
    let sessionID: SessionID = "cached-session"
    let stored = SessionSnapshot(
        id: sessionID,
        descriptor: SessionDescriptor(id: sessionID, title: "Stored"),
        messages: [ChatMessage(role: .user, content: MessageContent(text: "Existing"))]
    )
    let store = InMemorySessionStore(snapshots: [stored])
    let coordinator = SessionCoordinator(store: store)

    let first = try await coordinator.loadSession(id: sessionID)
    let second = try await coordinator.loadSession(id: sessionID)

    #expect(first?.id == sessionID)
    #expect(second?.id == sessionID)
    #expect(await store.loadedIDs == [sessionID])
}
