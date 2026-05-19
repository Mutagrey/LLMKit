import SwiftUI

public struct ChatScreen: View {
    private enum ScrollAnchor {
        static let bottom = "chat-bottom-anchor"
    }

    private let title: String
    @State private var viewModel: ChatViewModel
    @State private var draftText: String
    @FocusState private var isComposerFocused: Bool

    public init(
        title: String = "Chat",
        viewModel: ChatViewModel = ChatViewModel(),
        draftText: String = ""
    ) {
        self.title = title
        self._viewModel = State(initialValue: viewModel)
        self._draftText = State(initialValue: draftText)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ChatTranscriptView(
                title: title,
                transcriptItems: viewModel.transcriptItems,
                streamingText: viewModel.streamingText,
                isStreaming: viewModel.isStreaming,
                lastError: viewModel.lastError,
                bottomAnchorID: ScrollAnchor.bottom
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: dismissKeyboard)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChatComposer(
                    draftText: $draftText,
                    isComposerFocused: $isComposerFocused,
                    isStreaming: viewModel.isStreaming,
                    send: sendDraft
                )
            }
            .navigationTitle(title)
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .background(.background)
            .onAppear {
                scrollToBottom(with: proxy, animated: false)
            }
            .onChange(of: viewModel.transcriptItems.count) { _, _ in
                scrollToBottom(with: proxy)
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                scrollToBottom(with: proxy, animated: false)
            }
            .onChange(of: viewModel.isStreaming) { _, _ in
                scrollToBottom(with: proxy, animated: false)
            }
            .onChange(of: viewModel.lastError) { _, _ in
                scrollToBottom(with: proxy)
            }
        }
    }

    private func sendDraft() {
        let text = draftText
        draftText = ""
        viewModel.submit(text)
    }

    private func dismissKeyboard() {
        isComposerFocused = false
    }

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool = true) {
        let scrollAction = {
            proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.18), scrollAction)
        } else {
            scrollAction()
        }
    }
}
