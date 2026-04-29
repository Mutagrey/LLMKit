import Foundation
import LLMCore
import LLMProtocols

public actor AutomatedConversationCoordinator {
    private let sessionService: any SessionService
    private let chatService: any ChatService
    private let promptRenderer: any AutomatedConversationPromptRendering
    private let contextWindowManager: ContextWindowManager

    public init(
        sessionService: any SessionService,
        chatService: any ChatService,
        promptRenderer: any AutomatedConversationPromptRendering,
        contextWindowManager: ContextWindowManager = ContextWindowManager()
    ) {
        self.sessionService = sessionService
        self.chatService = chatService
        self.promptRenderer = promptRenderer
        self.contextWindowManager = contextWindowManager
    }

    public func start(sessionID: SessionID) async throws -> SessionSnapshot {
        try await updateRunState(sessionID: sessionID) { state in
            AutomatedConversationRunState(
                phase: .running,
                completedTurns: state.completedTurns,
                nextParticipantIndex: state.nextParticipantIndex,
                lastErrorMessage: nil,
                lastUpdatedAt: Date()
            )
        }
    }

    public func pause(sessionID: SessionID) async throws -> SessionSnapshot {
        try await updateRunState(sessionID: sessionID) { state in
            AutomatedConversationRunState(
                phase: .paused,
                completedTurns: state.completedTurns,
                nextParticipantIndex: state.nextParticipantIndex,
                lastErrorMessage: state.lastErrorMessage,
                lastUpdatedAt: Date()
            )
        }
    }

    public func resume(sessionID: SessionID) async throws -> SessionSnapshot {
        try await start(sessionID: sessionID)
    }

    public func runBatch(sessionID: SessionID, maxTurns: Int) async throws -> SessionSnapshot {
        var latest = try await start(sessionID: sessionID)
        var remainingTurns = max(1, maxTurns)
        while remainingTurns > 0 {
            latest = try await runTurn(sessionID: latest.id)
            guard latest.automationState?.phase == .running else {
                return latest
            }
            remainingTurns -= 1
        }
        return latest
    }

    public func runTurn(sessionID: SessionID) async throws -> SessionSnapshot {
        do {
            var snapshot = try await requiredAutomationSnapshot(id: sessionID)
            let runState = snapshot.automationState ?? AutomatedConversationRunState()
            guard runState.phase != .completed else {
                return snapshot
            }
            guard let definition = snapshot.automationDefinition else {
                throw LLMError.executionFailed("Automated conversation definition is missing.")
            }
            guard !definition.participants.isEmpty else {
                throw LLMError.executionFailed("Automated conversations require at least one participant.")
            }

            if runState.completedTurns >= definition.maxTurns {
                snapshot = try await save(snapshot.withAutomationState(runState.transitioning(to: .completed)))
                return snapshot
            }

            let participant = definition.participants[runState.nextParticipantIndex % definition.participants.count]
            let participantRequirements = requirements(
                for: participant,
                definition: definition,
                snapshot: snapshot
            )

            snapshot = try await compactIfNeeded(snapshot, definition: definition, requirements: participantRequirements)

            let promptMessages = promptRenderer.participantMessages(
                definition: definition,
                participant: participant,
                summary: snapshot.summary,
                recentMessages: snapshot.messages
            )
            let reply = try await collectAssistantMessage(
                ChatRequest(messages: promptMessages, requirements: participantRequirements, sessionID: snapshot.id)
            )

            let storedMessage = ChatMessage(
                role: .assistant,
                content: MessageContent(text: "\(participant.displayName): \(reply.content.text.trimmingCharacters(in: .whitespacesAndNewlines))"),
                createdAt: reply.createdAt
            )
            snapshot = try await sessionService.append(storedMessage, to: snapshot.id)
            let updatedState = AutomatedConversationRunState(
                phase: runState.completedTurns + 1 >= definition.maxTurns ? .completed : .running,
                completedTurns: runState.completedTurns + 1,
                nextParticipantIndex: (runState.nextParticipantIndex + 1) % definition.participants.count,
                lastErrorMessage: nil,
                lastUpdatedAt: Date()
            )
            snapshot = try await save(snapshot.withAutomationState(updatedState))
            return snapshot
        } catch let error as LLMError {
            return try await markFailed(sessionID: sessionID, message: errorMessage(for: error))
        } catch {
            return try await markFailed(sessionID: sessionID, message: error.localizedDescription)
        }
    }

    public func resumeRunningSessions(maxTurnsPerSession: Int = 1) async throws -> [SessionSnapshot] {
        let overviews = try await sessionService.listSessions()
        var snapshots: [SessionSnapshot] = []
        for overview in overviews where overview.kind == .automatedConversation && overview.automationState?.phase == .running {
            snapshots.append(try await runBatch(sessionID: overview.id, maxTurns: maxTurnsPerSession))
        }
        return snapshots
    }

    private func compactIfNeeded(
        _ snapshot: SessionSnapshot,
        definition: AutomatedConversationDefinition,
        requirements: ExecutionRequirements
    ) async throws -> SessionSnapshot {
        let decision = contextWindowManager.plan(
            for: snapshot,
            contextWindowTokens: requirements.budget?.maxInputTokens
        )
        guard decision.requiresCompaction else {
            return snapshot
        }

        let summaryMessages = promptRenderer.summaryMessages(
            definition: definition,
            currentSummary: snapshot.summary,
            messagesToCompress: decision.messagesToCompress
        )
        let summaryReply = try await collectAssistantMessage(
            ChatRequest(messages: summaryMessages, requirements: requirements, sessionID: snapshot.id)
        )
        let existingCount = snapshot.summary?.sourceMessageCount ?? 0
        let updatedSummary = SessionSummary(
            text: summaryReply.content.text.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceMessageCount: existingCount + decision.messagesToCompress.count
        )
        let compactedSnapshot = SessionSnapshot(
            id: snapshot.id,
            descriptor: SessionDescriptor(
                id: snapshot.descriptor.id,
                title: snapshot.descriptor.title,
                createdAt: snapshot.descriptor.createdAt,
                updatedAt: Date()
            ),
            kind: snapshot.kind,
            messages: decision.recentMessages,
            summary: updatedSummary,
            executionRequirements: snapshot.executionRequirements,
            automationDefinition: snapshot.automationDefinition,
            automationState: snapshot.automationState
        )
        return try await save(compactedSnapshot)
    }

    private func collectAssistantMessage(_ request: ChatRequest) async throws -> ChatMessage {
        var streamedText = ""
        var completed: ChatMessage?
        for try await event in chatService.send(request) {
            switch event {
            case .delta(let text):
                streamedText.append(text)
            case .completed(let result):
                completed = result.message
            case .failed(let error):
                throw error
            case .started, .toolCallRequested, .toolCallCompleted:
                break
            }
        }
        if let completed {
            return completed
        }
        guard !streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.executionFailed("Chat stream finished without an assistant response.")
        }
        return ChatMessage(role: .assistant, content: MessageContent(text: streamedText))
    }

    private func requiredAutomationSnapshot(id: SessionID) async throws -> SessionSnapshot {
        guard let snapshot = try await sessionService.loadSession(id: id) else {
            throw LLMError.executionFailed("Session \(id.rawValue) could not be loaded.")
        }
        guard snapshot.kind == .automatedConversation else {
            throw LLMError.executionFailed("Session \(id.rawValue) is not an automated conversation.")
        }
        return snapshot
    }

    private func updateRunState(
        sessionID: SessionID,
        transform: (AutomatedConversationRunState) -> AutomatedConversationRunState
    ) async throws -> SessionSnapshot {
        let snapshot = try await requiredAutomationSnapshot(id: sessionID)
        let nextState = transform(snapshot.automationState ?? AutomatedConversationRunState())
        return try await save(snapshot.withAutomationState(nextState))
    }

    private func requirements(
        for participant: AutomatedConversationParticipant,
        definition: AutomatedConversationDefinition,
        snapshot: SessionSnapshot
    ) -> ExecutionRequirements {
        let base = definition.sharedExecutionRequirements
            ?? snapshot.executionRequirements
            ?? ExecutionRequirements(requiredCapabilities: [.chat], preferredLatency: .background)
        return base.updating(
            requiredCapabilities: base.requiredCapabilities.union([.chat]),
            selectionPolicy: participant.selectionPolicy ?? base.selectionPolicy,
            preferredLatency: .background
        )
    }

    private func save(_ snapshot: SessionSnapshot) async throws -> SessionSnapshot {
        try await sessionService.saveSession(snapshot)
        return snapshot
    }

    private func markFailed(sessionID: SessionID, message: String) async throws -> SessionSnapshot {
        let snapshot = try await requiredAutomationSnapshot(id: sessionID)
        let state = snapshot.automationState ?? AutomatedConversationRunState()
        let failed = AutomatedConversationRunState(
            phase: .failed,
            completedTurns: state.completedTurns,
            nextParticipantIndex: state.nextParticipantIndex,
            lastErrorMessage: message,
            lastUpdatedAt: Date()
        )
        return try await save(snapshot.withAutomationState(failed))
    }

    private func errorMessage(for error: LLMError) -> String {
        switch error {
        case .executionFailed(let message),
             .toolExecutionFailed(let message),
             .downloadFailed(let message),
             .verificationFailed(let message),
             .invalidStructuredOutput(let message),
             .unsupportedLocale(let message),
             .modelSelectionFailed(let message):
            return message
        case .modelNotInstalled(let modelID):
            return "\(modelID.rawValue) is not installed."
        case .unsupportedCapabilities:
            return "The selected model does not support this automated conversation."
        case .cancelled:
            return "Cancelled."
        case .unavailable:
            return "The selected model is unavailable."
        case .compilationFailed:
            return "Model compilation failed."
        }
    }
}

private extension SessionSnapshot {
    func withAutomationState(_ automationState: AutomatedConversationRunState) -> SessionSnapshot {
        SessionSnapshot(
            id: id,
            descriptor: SessionDescriptor(
                id: descriptor.id,
                title: descriptor.title,
                createdAt: descriptor.createdAt,
                updatedAt: Date()
            ),
            kind: kind,
            messages: messages,
            summary: summary,
            executionRequirements: executionRequirements,
            automationDefinition: automationDefinition,
            automationState: automationState
        )
    }
}

private extension AutomatedConversationRunState {
    func transitioning(to phase: AutomatedConversationRunPhase) -> AutomatedConversationRunState {
        AutomatedConversationRunState(
            phase: phase,
            completedTurns: completedTurns,
            nextParticipantIndex: nextParticipantIndex,
            lastErrorMessage: phase == .running ? nil : lastErrorMessage,
            lastUpdatedAt: Date()
        )
    }
}
