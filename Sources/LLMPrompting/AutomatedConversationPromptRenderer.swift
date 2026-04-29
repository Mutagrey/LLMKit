import Foundation
import LLMCore
import LLMProtocols

public struct AutomatedConversationPromptRenderer: AutomatedConversationPromptRendering {
    private let assembler: PromptAssembler

    public init(assembler: PromptAssembler = PromptAssembler()) {
        self.assembler = assembler
    }

    public func summaryMessages(
        definition: AutomatedConversationDefinition,
        currentSummary: SessionSummary?,
        messagesToCompress: [ChatMessage]
    ) -> [ChatMessage] {
        let systemTemplate = PromptTemplate(
            id: "automation.summary.system",
            version: PromptVersion("v1"),
            fragments: [
                PromptFragment("You maintain a compact running summary for an automated discussion."),
                PromptFragment("Topic: {{topic}}"),
                PromptFragment("Preserve key claims, disagreements, decisions, and unanswered questions."),
                PromptFragment("Write plain prose without bullet lists unless the discussion already uses them.")
            ]
        )
        let userTemplate = PromptTemplate(
            id: "automation.summary.user",
            version: PromptVersion("v1"),
            fragments: [
                PromptFragment("Current summary:"),
                PromptFragment("{{currentSummary}}"),
                PromptFragment(""),
                PromptFragment("New transcript to compress:"),
                PromptFragment("{{transcript}}"),
                PromptFragment(""),
                PromptFragment("Return only the updated summary.")
            ]
        )

        let system = assembler.assemble(systemTemplate, context: PromptContext(
            variables: ["topic": definition.topic]
        )).assembledPrompt
        let user = assembler.assemble(userTemplate, context: PromptContext(
            variables: [
                "currentSummary": currentSummary?.text ?? "No existing summary.",
                "transcript": transcriptText(for: messagesToCompress)
            ]
        )).assembledPrompt

        return [
            ChatMessage(role: .system, content: MessageContent(text: system)),
            ChatMessage(role: .user, content: MessageContent(text: user))
        ]
    }

    public func participantMessages(
        definition: AutomatedConversationDefinition,
        participant: AutomatedConversationParticipant,
        summary: SessionSummary?,
        recentMessages: [ChatMessage]
    ) -> [ChatMessage] {
        let systemTemplate = PromptTemplate(
            id: "automation.turn.system",
            version: PromptVersion("v1"),
            fragments: [
                PromptFragment("You are participating in an automated multi-speaker discussion."),
                PromptFragment("Topic: {{topic}}"),
                PromptFragment("Speaker name: {{name}}"),
                PromptFragment("Role: {{role}}"),
                PromptFragment("Role instructions: {{instructions}}"),
                PromptFragment("Respond with one natural turn from this speaker only.")
            ]
        )
        let userTemplate = PromptTemplate(
            id: "automation.turn.user",
            version: PromptVersion("v1"),
            fragments: [
                PromptFragment("Running summary:"),
                PromptFragment("{{summary}}"),
                PromptFragment(""),
                PromptFragment("Recent transcript:"),
                PromptFragment("{{transcript}}"),
                PromptFragment(""),
                PromptFragment("Write the next turn for {{name}}.")
            ]
        )

        let system = assembler.assemble(systemTemplate, context: PromptContext(
            variables: [
                "topic": definition.topic,
                "name": participant.displayName,
                "role": participant.role,
                "instructions": participant.instructions.isEmpty ? "No extra instructions." : participant.instructions
            ]
        )).assembledPrompt
        let user = assembler.assemble(userTemplate, context: PromptContext(
            variables: [
                "name": participant.displayName,
                "summary": summary?.text ?? "No summary yet.",
                "transcript": transcriptText(for: recentMessages)
            ]
        )).assembledPrompt

        return [
            ChatMessage(role: .system, content: MessageContent(text: system)),
            ChatMessage(role: .user, content: MessageContent(text: user))
        ]
    }

    private func transcriptText(for messages: [ChatMessage]) -> String {
        messages.map { message in
            "[\(message.role.rawValue)] \(message.content.text)"
        }.joined(separator: "\n")
    }
}
