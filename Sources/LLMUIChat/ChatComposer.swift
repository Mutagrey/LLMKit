import SwiftUI

struct ChatComposer: View {
    @Binding var draftText: String
    let isComposerFocused: FocusState<Bool>.Binding
    let isStreaming: Bool
    let send: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

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
                    Image(systemName: "paperplane.fill")
                        .font(.headline.weight(.semibold))
                        .frame(width: 30, height: 30)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderedProminent)
                .clipShape(.capsule)
                .disabled(isSendDisabled)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.bar)
        }
    }

    private var isSendDisabled: Bool {
        if isStreaming {
            return true
        }
        return draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
