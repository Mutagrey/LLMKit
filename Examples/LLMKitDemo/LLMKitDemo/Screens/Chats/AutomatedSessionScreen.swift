import LLMCore
import LLMUIChat
import SwiftUI

struct AutomatedSessionScreen: View {
    let viewModel: DemoViewModel
    let configuration: DemoRuntimeConfiguration
    let onSessionChanged: @Sendable () async -> Void

    @State private var snapshot: SessionSnapshot
    @State private var isRunningAction = false

    init(
        snapshot: SessionSnapshot,
        viewModel: DemoViewModel,
        configuration: DemoRuntimeConfiguration,
        onSessionChanged: @escaping @Sendable () async -> Void
    ) {
        self.viewModel = viewModel
        self.configuration = configuration
        self.onSessionChanged = onSessionChanged
        self._snapshot = State(initialValue: snapshot)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let definition = snapshot.automationDefinition {
                    AutoDialogHeader(
                        definition: definition,
                        statusLine: statusLine,
                        summary: snapshot.summary?.text
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(snapshot.messages) { message in
                            Text(message.content.text)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(snapshot.descriptor.title ?? "Auto dialog")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    run(.start)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }

                Button {
                    run(.step)
                } label: {
                    Label("Step", systemImage: "forward.frame")
                }

                Button {
                    run(.pause)
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunningAction)
            .padding()
            .background(.background)
        }
        .overlay {
            if isRunningAction {
                ProgressView()
            }
        }
    }

    private var statusLine: String {
        let state = snapshot.automationState ?? AutomatedConversationRunState()
        let errorSuffix = state.lastErrorMessage.map { " · \($0)" } ?? ""
        return "\(state.phase.rawValue.capitalized) · \(state.completedTurns) turns\(errorSuffix)"
    }

    private func run(_ action: AutomationAction) {
        guard !isRunningAction else {
            return
        }

        isRunningAction = true
        Task {
            defer {
                Task { @MainActor in
                    isRunningAction = false
                }
            }

            let coordinator = configuration.makeAutomationCoordinator()
            do {
                try await viewModel.validateAutomatedSession(snapshot)
                let updated: SessionSnapshot
                switch action {
                case .start:
                    updated = try await coordinator.runBatch(sessionID: snapshot.id, maxTurns: 3)
                case .step:
                    updated = try await coordinator.runBatch(sessionID: snapshot.id, maxTurns: 1)
                case .pause:
                    updated = try await coordinator.pause(sessionID: snapshot.id)
                }

                await MainActor.run {
                    snapshot = updated
                }
                await onSessionChanged()
            } catch {
                await MainActor.run {
                    snapshot = snapshot.withFailureMessage(ChatErrorPresentation(error: error).message)
                }
            }
        }
    }

    private enum AutomationAction {
        case start
        case step
        case pause
    }
}

private struct AutoDialogHeader: View {
    let definition: AutomatedConversationDefinition
    let statusLine: String
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(definition.topic)
                .font(.headline)
            Text(definition.participants.map(\.displayName).joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(statusLine)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let summary, !summary.isEmpty {
                Divider()
                Text("Summary")
                    .font(.headline)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension SessionSnapshot {
    func withFailureMessage(_ message: String) -> SessionSnapshot {
        SessionSnapshot(
            id: id,
            descriptor: descriptor,
            kind: kind,
            messages: messages,
            summary: summary,
            executionRequirements: executionRequirements,
            automationDefinition: automationDefinition,
            automationState: AutomatedConversationRunState(
                phase: .failed,
                completedTurns: automationState?.completedTurns ?? 0,
                nextParticipantIndex: automationState?.nextParticipantIndex ?? 0,
                lastErrorMessage: message,
                lastUpdatedAt: Date()
            )
        )
    }
}
