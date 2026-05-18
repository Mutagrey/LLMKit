import LLMCore
import LLMUIChat
import SwiftUI

struct ManualSessionScreen: View {
    @State private var viewModel: ChatViewModel

    private let title: String
    private let descriptor: ModelDescriptor?

    init(
        snapshot: SessionSnapshot,
        descriptor: ModelDescriptor?,
        preflight: @escaping @MainActor @Sendable () async throws -> Void,
        configuration: DemoRuntimeConfiguration,
        onSessionChanged: @escaping @Sendable () async -> Void
    ) {
        self.descriptor = descriptor
        self.title = snapshot.descriptor.title ?? "New chat"
        self._viewModel = State(initialValue: ChatViewModel(
            messages: snapshot.messages,
            chatService: configuration.container.chat,
            requirements: snapshot.executionRequirements ?? ExecutionRequirements(requiredCapabilities: [.chat]),
            sessionID: snapshot.id,
            onMessageAppended: { message in
                Task {
                    if (try? await configuration.container.sessions.append(message, to: snapshot.id)) != nil {
                        await onSessionChanged()
                    }
                }
            },
            beforeSend: {
                try await preflight()
            }
        ))
    }

    var body: some View {
        ChatScreen(
            title: titleLine,
            viewModel: viewModel
        )
    }

    private var titleLine: String {
        if let descriptor {
            return "\(title) · \(descriptor.displayName) · \(demoBackendTitle(descriptor.backend))"
        }
        return title
    }
}
