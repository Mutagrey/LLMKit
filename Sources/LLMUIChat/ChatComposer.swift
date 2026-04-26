import SwiftUI

struct ChatComposer: View {
    @Binding var draftText: String
    let isComposerFocused: FocusState<Bool>.Binding
    let isStreaming: Bool
    let send: () -> Void
    let stop: () -> Void
    let dismissKeyboard: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask anything", text: $draftText, axis: .vertical)
                        .focused(isComposerFocused)
                        .submitLabel(.return)
                        .lineLimit(1...6)
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                        }

                    Button(action: isStreaming ? stop : send) {
                        Image(systemName: isStreaming ? "stop.fill" : "paperplane.fill")
                            .font(.headline.weight(.semibold))
                            .frame(width: 30, height: 30)
                            .contentTransition(.symbolEffect(.replace))
                        .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(.capsule)
                    .disabled(isSendDisabled)
                    .accessibilityLabel(isStreaming ? "Stop" : "Send")
                }

                if isStreaming {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Generating response")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Stop", action: stop)
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.bar)
        }
    }

    private var isSendDisabled: Bool {
        if isStreaming {
            return false
        }
        return draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
