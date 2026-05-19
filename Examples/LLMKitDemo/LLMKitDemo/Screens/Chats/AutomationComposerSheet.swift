import LLMCore
import LLMUIChat
import SwiftUI

struct AutomationComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: DemoViewModel
    let onCreate: (SessionID) -> Void

    @State private var title = ""
    @State private var topic = ""
    @State private var maxTurns = 8
    @State private var usesSharedModel = true
    @State private var participants: [AutomationParticipantDraft]

    init(viewModel: DemoViewModel, onCreate: @escaping (SessionID) -> Void) {
        self.viewModel = viewModel
        self.onCreate = onCreate
        let defaultModelID = viewModel.selectedModel?.id
        self._participants = State(initialValue: [
            AutomationParticipantDraft(
                displayName: "Researcher",
                role: "Explore the topic and add concrete detail.",
                instructions: "",
                modelID: defaultModelID
            ),
            AutomationParticipantDraft(
                displayName: "Reviewer",
                role: "Challenge weak assumptions and tighten the argument.",
                instructions: "",
                modelID: defaultModelID
            )
        ])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Conversation") {
                    TextField("Title", text: $title)
                    TextField("Topic", text: $topic, axis: .vertical)
                    Stepper("Max Turns: \(maxTurns)", value: $maxTurns, in: 2...64, step: 2)
                    Toggle("Shared model", isOn: $usesSharedModel)
                }

                Section("Participants") {
                    ForEach($participants) { draft in
                        ParticipantDraftFields(
                            draft: draft,
                            usesSharedModel: usesSharedModel,
                            availableModels: availableModels
                        )
                    }
                    .onDelete { offsets in
                        participants.remove(atOffsets: offsets)
                    }

                    Button(action: addParticipant) {
                        Label("Add participant", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Auto Dialog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createSession)
                        .disabled(trimmedTopic.isEmpty || participants.isEmpty)
                }
            }
        }
    }

    private var availableModels: [ModelDescriptor] {
        viewModel.chatSelectableModels
    }

    private var trimmedTopic: String {
        topic.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addParticipant() {
        participants.append(AutomationParticipantDraft(
            displayName: "Speaker \(participants.count + 1)",
            role: "Contribute another perspective to the discussion.",
            instructions: "",
            modelID: viewModel.selectedModel?.id
        ))
    }

    private func createSession() {
        let baseRequirements = sharedRequirements()
        let definition = AutomatedConversationDefinition(
            topic: trimmedTopic,
            participants: participants.map(automatedParticipant),
            sharedExecutionRequirements: baseRequirements,
            maxTurns: maxTurns,
            backgroundPolicy: .bestEffort
        )

        Task {
            do {
                let snapshot = try await viewModel.createAutomatedSession(
                    title: trimmedTitle.isEmpty ? trimmedTopic : trimmedTitle,
                    definition: definition,
                    executionRequirements: baseRequirements
                )
                await MainActor.run {
                    dismiss()
                    onCreate(snapshot.id)
                }
            } catch {
                await MainActor.run {
                    viewModel.setLastErrorMessage(ChatErrorPresentation(error: error).message)
                }
            }
        }
    }

    private func automatedParticipant(_ draft: AutomationParticipantDraft) -> AutomatedConversationParticipant {
        AutomatedConversationParticipant(
            id: draft.id.uuidString,
            displayName: draft.displayName,
            role: draft.role,
            instructions: draft.instructions,
            selectionPolicy: usesSharedModel ? nil : draft.modelID.map { .require($0) }
        )
    }

    private func sharedRequirements() -> ExecutionRequirements {
        if usesSharedModel, let model = viewModel.selectedModel {
            return viewModel.requirements(for: model, preferredLatency: .background)
        }

        let contextLimit = participants
            .compactMap { viewModel.model(for: $0.modelID)?.contextWindowTokens }
            .min()
        return ExecutionRequirements(
            requiredCapabilities: [.chat],
            selectionPolicy: .automatic,
            executionMode: viewModel.executionMode,
            preferredLatency: .background,
            qualityTier: viewModel.qualityTier,
            privacyMode: viewModel.privacyMode,
            budget: viewModel.executionBudget(selectedModelContextWindowTokens: contextLimit)
        )
    }
}

private struct ParticipantDraftFields: View {
    @Binding var draft: AutomationParticipantDraft

    let usesSharedModel: Bool
    let availableModels: [ModelDescriptor]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $draft.displayName)
            TextField("Role", text: $draft.role, axis: .vertical)
            TextField("Instructions", text: $draft.instructions, axis: .vertical)

            if !usesSharedModel {
                Picker("Model", selection: $draft.modelID) {
                    Text("No model").tag(Optional<ModelID>.none)
                    ForEach(availableModels, id: \.id) { descriptor in
                        Text(descriptor.displayName).tag(Optional(descriptor.id))
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct AutomationParticipantDraft: Identifiable, Hashable {
    let id = UUID()
    var displayName: String
    var role: String
    var instructions: String
    var modelID: ModelID?
}
