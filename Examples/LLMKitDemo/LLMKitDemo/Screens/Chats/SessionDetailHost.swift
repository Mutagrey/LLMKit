import LLMCore
import LLMUIChat
import SwiftUI

struct SessionDetailHost: View {
    let sessionID: SessionID
    let viewModel: DemoViewModel
    let skillStore: DemoPromptSkillStore
    let configuration: DemoRuntimeConfiguration

    @State private var snapshot: SessionSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let snapshot {
                switch snapshot.kind {
                case .manualChat:
                    ManualSessionScreen(
                        snapshot: snapshot,
                        descriptor: viewModel.backendDescriptor(for: snapshot.overview),
                        skillStore: skillStore,
                        preflight: {
                            try await viewModel.validateExecutionRequirements(
                                snapshot.executionRequirements ?? ExecutionRequirements(requiredCapabilities: [.chat]),
                                context: "Manual chat"
                            )
                        },
                        configuration: configuration,
                        onSessionChanged: {
                            try? await viewModel.refreshSessions()
                        }
                    )
                case .automatedConversation:
                    AutomatedSessionScreen(
                        snapshot: snapshot,
                        viewModel: viewModel,
                        configuration: configuration,
                        onSessionChanged: {
                            try? await viewModel.refreshSessions()
                        }
                    )
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Session Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
            }
        }
        .task(id: sessionID) {
            await loadSession()
        }
    }

    private func loadSession() async {
        do {
            snapshot = try await viewModel.loadSession(id: sessionID)
            errorMessage = snapshot == nil ? "The selected session could not be loaded." : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
