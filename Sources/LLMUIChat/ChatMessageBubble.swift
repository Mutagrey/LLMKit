import LLMCore
import SwiftUI

struct ChatMessageBubble: View {
    let message: ChatMessage
    var isStreamingPreview = false

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 44)
            }

            Text(message.content.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if isStreamingPreview {
                        ProgressView()
                            .controlSize(.mini)
                            .padding(.trailing, 8)
                            .padding(.bottom, 6)
                    }
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

    private var bubbleBackground: Color {
        message.role == .user ? .accentColor.opacity(0.14) : .secondary.opacity(0.10)
    }
}
