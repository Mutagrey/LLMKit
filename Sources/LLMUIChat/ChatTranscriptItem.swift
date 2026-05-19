import LLMCore

public struct ChatTranscriptItem: Identifiable, Hashable, Sendable {
    public enum Content: Hashable, Sendable {
        case message(ChatMessage, runtimeMetrics: [TelemetryEvent])
        case tool(ToolCallPresentation)
    }

    public let id: String
    public let content: Content

    public static func message(
        _ message: ChatMessage,
        runtimeMetrics: [TelemetryEvent] = []
    ) -> ChatTranscriptItem {
        ChatTranscriptItem(
            id: "message:\(message.id.uuidString)",
            content: .message(message, runtimeMetrics: runtimeMetrics)
        )
    }

    public static func tool(_ toolCall: ToolCallPresentation) -> ChatTranscriptItem {
        ChatTranscriptItem(id: "tool:\(toolCall.id.rawValue)", content: .tool(toolCall))
    }

    var toolCallID: ToolCallID? {
        guard case .tool(let toolCall) = content else {
            return nil
        }
        return toolCall.id
    }
}
