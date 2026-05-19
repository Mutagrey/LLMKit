import LLMCore
import LLMUIObservability
import SwiftUI

struct ChatMessageBubble: View {
    let message: ChatMessage
    var runtimeMetricsSummary: RuntimeMetricsSummary? = nil

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 44)
            }

            VStack(alignment: bubbleContentAlignment, spacing: 5) {
                Text(message.content.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                if let runtimeMetricsSummary, !runtimeMetricsSummary.isEmpty {
                    RuntimeMetricsInlineSummaryView(summary: runtimeMetricsSummary)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(bubbleBorder, lineWidth: 1)
            }

            if message.role != .user {
                Spacer(minLength: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        message.role == .user ? .trailing : .leading
    }

    private var bubbleContentAlignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var bubbleBackground: Color {
        message.role == .user ? .accentColor.opacity(0.24) : .secondary.opacity(0.16)
    }

    private var bubbleBorder: Color {
        message.role == .user ? .accentColor.opacity(0.30) : .secondary.opacity(0.22)
    }
}
