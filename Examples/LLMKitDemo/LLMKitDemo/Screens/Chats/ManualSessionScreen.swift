import LLMCore
import LLMUIChat
import LLMUIModels
import SwiftUI

struct ManualSessionScreen: View {
    @State private var viewModel: ChatViewModel

    private let title: String
    private let descriptor: ModelDescriptor?
    private let sessionID: SessionID
    private let skillStore: DemoPromptSkillStore

    init(
        snapshot: SessionSnapshot,
        descriptor: ModelDescriptor?,
        skillStore: DemoPromptSkillStore,
        preflight: @escaping @MainActor @Sendable () async throws -> Void,
        configuration: DemoRuntimeConfiguration,
        onSessionChanged: @escaping @Sendable () async -> Void
    ) {
        self.descriptor = descriptor
        self.sessionID = snapshot.id
        self.skillStore = skillStore
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
            },
            runtimeMetricsProvider: {
                await configuration.metricsCollector.snapshot()
            },
            transientMessagesProvider: {
                skillStore.transientMessages(for: snapshot.id)
            },
            transientContextSignatureProvider: {
                skillStore.transientSignature(for: snapshot.id)
            }
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            ManualChatHeader(
                sessionID: sessionID,
                descriptor: descriptor,
                skillStore: skillStore
            )

            Divider()

            ChatScreen(
                title: titleLine,
                viewModel: viewModel
            )
        }
    }

    private var titleLine: String {
        if let descriptor {
            return "\(title) · \(descriptor.displayName) · \(ModelFormatting.backendTitle(descriptor.backend))"
        }
        return title
    }
}
