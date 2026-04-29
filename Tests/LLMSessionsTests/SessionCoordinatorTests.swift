import Foundation
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

    func listSessions() async throws -> [SessionOverview] {
        snapshots.values.map(\.overview).sorted { $0.updatedAt > $1.updatedAt }
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

@Test func sessionCoordinatorCreatesAutomatedSessionWithExecutionProfile() async throws {
    let coordinator = SessionCoordinator()
    let requirements = ExecutionRequirements(
        requiredCapabilities: [.chat],
        selectionPolicy: .require("mlx-community.qwen"),
        preferredLatency: .background,
        budget: ExecutionBudget(maxInputTokens: 4096, maxOutputTokens: 512)
    )
    let definition = AutomatedConversationDefinition(
        topic: "Discuss model routing",
        participants: [
            AutomatedConversationParticipant(
                id: "speaker-a",
                displayName: "Planner",
                role: "Build the first position."
            ),
            AutomatedConversationParticipant(
                id: "speaker-b",
                displayName: "Reviewer",
                role: "Challenge the weak points."
            )
        ],
        sharedExecutionRequirements: requirements,
        maxTurns: 8
    )

    let snapshot = try await coordinator.createSession(
        title: "Routing Debate",
        kind: .automatedConversation,
        executionRequirements: requirements,
        automationDefinition: definition,
        automationState: AutomatedConversationRunState()
    )

    #expect(snapshot.kind == .automatedConversation)
    #expect(snapshot.executionRequirements == requirements)
    #expect(snapshot.automationDefinition?.topic == "Discuss model routing")
    #expect(snapshot.automationState?.phase == .idle)
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

@Test func sessionCoordinatorListsStoredSessionsWithoutLoadingSnapshots() async throws {
    let older = SessionSnapshot(
        id: "older",
        descriptor: SessionDescriptor(
            id: "older",
            title: "Older",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10)
        ),
        messages: [ChatMessage(role: .user, content: MessageContent(text: "Older"))]
    )
    let newer = SessionSnapshot(
        id: "newer",
        descriptor: SessionDescriptor(
            id: "newer",
            title: "Newer",
            createdAt: Date(timeIntervalSince1970: 20),
            updatedAt: Date(timeIntervalSince1970: 20)
        ),
        kind: .automatedConversation,
        messages: [ChatMessage(role: .assistant, content: MessageContent(text: "Newer"))],
        automationState: AutomatedConversationRunState(phase: .running)
    )
    let store = InMemorySessionStore(snapshots: [older, newer])
    let coordinator = SessionCoordinator(store: store)

    let sessions = try await coordinator.listSessions()

    #expect(sessions.map { $0.id } == ["newer", "older"])
    #expect(await store.loadedIDs.isEmpty)
}

@Test func sessionCoordinatorDeletesPersistedSession() async throws {
    let stored = SessionSnapshot(
        id: "delete-me",
        descriptor: SessionDescriptor(id: "delete-me", title: "Delete me")
    )
    let store = InMemorySessionStore(snapshots: [stored])
    let coordinator = SessionCoordinator(store: store)

    try await coordinator.deleteSession(id: stored.id)
    let loaded = try await coordinator.loadSession(id: stored.id)

    #expect(loaded == nil)
}
