import Foundation
import LLMCore
import LLMProtocols
import LLMSessions
import Testing

private struct StubPromptRenderer: AutomatedConversationPromptRendering {
    func summaryMessages(
        definition: AutomatedConversationDefinition,
        currentSummary: SessionSummary?,
        messagesToCompress: [ChatMessage]
    ) -> [ChatMessage] {
        [
            ChatMessage(role: .system, content: MessageContent(text: "summary")),
            ChatMessage(role: .user, content: MessageContent(text: messagesToCompress.map(\.content.text).joined(separator: "\n")))
        ]
    }

    func participantMessages(
        definition: AutomatedConversationDefinition,
        participant: AutomatedConversationParticipant,
        summary: SessionSummary?,
        recentMessages: [ChatMessage]
    ) -> [ChatMessage] {
        [
            ChatMessage(role: .system, content: MessageContent(text: "turn")),
            ChatMessage(role: .user, content: MessageContent(text: participant.displayName))
        ]
    }
}

private struct ScriptedChatService: ChatService {
    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let mode = request.messages.first?.content.text ?? ""
            let text = mode == "summary" ? "compressed summary" : "generated turn"
            continuation.yield(.completed(ChatResult(
                message: ChatMessage(role: .assistant, content: MessageContent(text: text))
            )))
            continuation.finish()
        }
    }
}

@Test func automatedConversationCoordinatorTransitionsBetweenRunStates() async throws {
    let sessions = SessionCoordinator()
    let requirements = ExecutionRequirements(
        requiredCapabilities: [.chat],
        selectionPolicy: .require("mlx-community.qwen"),
        preferredLatency: .background,
        budget: ExecutionBudget(maxInputTokens: 512, maxOutputTokens: 128)
    )
    let definition = AutomatedConversationDefinition(
        topic: "State machine",
        participants: [
            AutomatedConversationParticipant(id: "a", displayName: "Planner", role: "Propose a plan.")
        ],
        sharedExecutionRequirements: requirements,
        maxTurns: 2
    )
    let snapshot = try await sessions.createSession(
        title: "Automation",
        kind: .automatedConversation,
        executionRequirements: requirements,
        automationDefinition: definition,
        automationState: AutomatedConversationRunState()
    )
    let coordinator = AutomatedConversationCoordinator(
        sessionService: sessions,
        chatService: ScriptedChatService(),
        promptRenderer: StubPromptRenderer()
    )

    let running = try await coordinator.start(sessionID: snapshot.id)
    let paused = try await coordinator.pause(sessionID: snapshot.id)
    let resumed = try await coordinator.resume(sessionID: snapshot.id)

    #expect(running.automationState?.phase == .running)
    #expect(paused.automationState?.phase == .paused)
    #expect(resumed.automationState?.phase == .running)
}

@Test func automatedConversationCoordinatorCompactsTranscriptAndAppendsSpeakerTurn() async throws {
    let sessions = SessionCoordinator()
    let requirements = ExecutionRequirements(
        requiredCapabilities: [.chat],
        selectionPolicy: .require("mlx-community.qwen"),
        preferredLatency: .background,
        budget: ExecutionBudget(maxInputTokens: 20, maxOutputTokens: 128)
    )
    let definition = AutomatedConversationDefinition(
        topic: "Compaction",
        participants: [
            AutomatedConversationParticipant(id: "a", displayName: "Planner", role: "Advance the discussion.")
        ],
        sharedExecutionRequirements: requirements,
        maxTurns: 2
    )
    var snapshot = try await sessions.createSession(
        title: "Compaction",
        kind: .automatedConversation,
        executionRequirements: requirements,
        automationDefinition: definition,
        automationState: AutomatedConversationRunState()
    )
    snapshot = try await sessions.append(ChatMessage(role: .user, content: MessageContent(text: String(repeating: "alpha ", count: 20))), to: snapshot.id)
    snapshot = try await sessions.append(ChatMessage(role: .assistant, content: MessageContent(text: String(repeating: "beta ", count: 20))), to: snapshot.id)
    snapshot = try await sessions.append(ChatMessage(role: .user, content: MessageContent(text: String(repeating: "gamma ", count: 20))), to: snapshot.id)
    snapshot = try await sessions.saveAndReload(snapshot)

    let coordinator = AutomatedConversationCoordinator(
        sessionService: sessions,
        chatService: ScriptedChatService(),
        promptRenderer: StubPromptRenderer()
    )
    let updated = try await coordinator.runBatch(sessionID: snapshot.id, maxTurns: 1)

    #expect(updated.summary?.text == "compressed summary")
    #expect((updated.summary?.sourceMessageCount ?? 0) > 0)
    #expect(updated.messages.last?.content.text == "Planner: generated turn")
    #expect(updated.automationState?.completedTurns == 1)
}

private extension SessionCoordinator {
    func saveAndReload(_ snapshot: SessionSnapshot) async throws -> SessionSnapshot {
        try await saveSession(snapshot)
        return try await loadSession(id: snapshot.id) ?? snapshot
    }
}
