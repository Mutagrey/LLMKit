import LLMCore
import LLMUIChat
import LLMUIModels
import SwiftUI

struct NewManualChatSheet: View {
    let viewModel: DemoViewModel
    let skillStore: DemoPromptSkillStore
    let onCreate: (SessionID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedModelID: ModelID?
    @State private var selection: DemoPromptSkillSelection
    @State private var isCreating = false
    @State private var errorMessage: String?

    init(
        viewModel: DemoViewModel,
        skillStore: DemoPromptSkillStore,
        onCreate: @escaping (SessionID) -> Void
    ) {
        self.viewModel = viewModel
        self.skillStore = skillStore
        self.onCreate = onCreate
        self._selectedModelID = State(initialValue: viewModel.selectedModelID)
        self._selection = State(initialValue: skillStore.defaultSelection)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    Picker("Model", selection: $selectedModelID) {
                        ForEach(viewModel.chatSelectableModels, id: \.id) { descriptor in
                            Text(modelTitle(for: descriptor))
                                .tag(Optional(descriptor.id))
                        }
                    }

                    if let descriptor = selectedModel {
                        LabeledContent("Status", value: viewModel.statusText(for: descriptor))
                    }
                }

                Section("Main Skill") {
                    Picker("Main", selection: mainSkillID) {
                        ForEach(skillStore.skills) { skill in
                            Text(skill.title).tag(skill.id)
                        }
                    }
                }

                Section("Additional Skills") {
                    ForEach(skillStore.skills) { skill in
                        Toggle(isOn: includedBinding(for: skill)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(skill.title)
                                Text(skill.prompt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .disabled(skill.id == selection.mainSkillID)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        create()
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isCreating || selectedModelID == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var selectedModel: ModelDescriptor? {
        viewModel.model(for: selectedModelID)
    }

    private var mainSkillID: Binding<UUID> {
        Binding(
            get: { selection.mainSkillID },
            set: { selection = skillStore.makeSelection(selection, mainSkillID: $0) }
        )
    }

    private func includedBinding(for skill: DemoPromptSkill) -> Binding<Bool> {
        Binding(
            get: { selection.includedSkillIDs.contains(skill.id) },
            set: { _ in
                selection = skillStore.makeSelection(selection, togglingIncludedSkillID: skill.id)
            }
        )
    }

    private func modelTitle(for descriptor: ModelDescriptor) -> String {
        "\(descriptor.displayName) · \(ModelFormatting.backendTitle(descriptor.backend))"
    }

    private func create() {
        guard let selectedModelID else {
            return
        }

        isCreating = true
        errorMessage = nil
        Task {
            do {
                await MainActor.run {
                    viewModel.selectedModelID = selectedModelID
                }
                let session = try await viewModel.createManualSession()
                await MainActor.run {
                    skillStore.setSelection(selection, for: session.id)
                    onCreate(session.id)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = ChatErrorPresentation(error: error).message
                    isCreating = false
                }
            }
        }
    }
}
