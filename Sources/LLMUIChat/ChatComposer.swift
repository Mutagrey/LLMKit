import SwiftUI

struct ChatComposer: View {
    @Binding var draftText: String
    let isComposerFocused: FocusState<Bool>.Binding
    let isStreaming: Bool
    let send: () -> Void
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

                    Button(action: send) {
                        Group {
                            if isStreaming {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.headline.weight(.semibold))
                            }
                        }
                        .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(.capsule)
                    .disabled(isSendDisabled)
                    .accessibilityLabel("Send")
                }

                if isStreaming {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Generating response")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
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
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming
    }
}
