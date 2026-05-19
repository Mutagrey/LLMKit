import LLMCore
import LLMUIObservability
import SwiftUI

struct ChatTranscriptView: View {
    let title: String
    let transcriptItems: [ChatTranscriptItem]
    let streamingText: String
    let isStreaming: Bool
    let lastError: ChatErrorPresentation?
    let bottomAnchorID: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if isEmpty {
                    ContentUnavailableView(
                        "Start a Conversation",
                        systemImage: "bubble.left.and.text.bubble.right",
                        description: Text("Messages in \(title) stay compact and readable as the transcript grows.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    transcriptContent
                }

                Color.clear
                    .frame(height: 1)
                    .id(bottomAnchorID)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    private var isEmpty: Bool {
        transcriptItems.isEmpty && streamingText.isEmpty && !isStreaming && lastError == nil
    }

    @ViewBuilder
    private var transcriptContent: some View {
        ForEach(transcriptItems) { item in
            switch item.content {
            case .message(let message, let runtimeMetrics):
                ChatMessageBubble(
                    message: message,
                    runtimeMetricsSummary: RuntimeMetricsSummary(events: runtimeMetrics)
                )
            case .tool(let toolCall):
                ChatToolActivityCard(toolCall: toolCall)
            }
        }

        if !streamingText.isEmpty {
            ChatMessageBubble(
                message: ChatMessage(
                    role: .assistant,
                    content: MessageContent(text: streamingText)
                )
            )
        }

        if isStreaming {
            ChatGeneratingStatusRow()
        }

        if let lastError {
            ChatErrorNoticeCard(error: lastError)
        }
    }
}

private struct ChatGeneratingStatusRow: View {
    var body: some View {
        HStack(spacing: 7) {
            ProgressView()
                .controlSize(.mini)
            Text("Generating response")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
