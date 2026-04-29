import LLMCore

public protocol AutomatedConversationPromptRendering: Sendable {
    func summaryMessages(
        definition: AutomatedConversationDefinition,
        currentSummary: SessionSummary?,
        messagesToCompress: [ChatMessage]
    ) -> [ChatMessage]

    func participantMessages(
        definition: AutomatedConversationDefinition,
        participant: AutomatedConversationParticipant,
        summary: SessionSummary?,
        recentMessages: [ChatMessage]
    ) -> [ChatMessage]
}
