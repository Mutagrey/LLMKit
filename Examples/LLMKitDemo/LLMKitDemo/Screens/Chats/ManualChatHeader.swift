import LLMCore
import LLMDeviceProfiling
import LLMUIModels
import LLMUIObservability
import SwiftUI

struct ManualChatHeader: View {
    let sessionID: SessionID
    let descriptor: ModelDescriptor?
    let skillStore: DemoPromptSkillStore

    @State private var profile = DeviceProfileCollector().currentProfile()
    @State private var isPresentingSkillPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(modelLine)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        FreeMemoryIndicatorView(
                            availableBytes: profile.availableProcessMemoryBytes,
                            totalBytes: profile.physicalMemoryBytes
                        )

                        Text("·")
                            .foregroundStyle(.tertiary)

                        Text(skillStore.selectedSkillTitles(for: selection))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    isPresentingSkillPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Edit chat skills")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .task {
            await refreshProfileLoop()
        }
        .sheet(isPresented: $isPresentingSkillPicker) {
            ChatSkillSelectionSheet(
                sessionID: sessionID,
                skillStore: skillStore
            )
        }
    }

    private var selection: DemoPromptSkillSelection {
        skillStore.selection(for: sessionID)
    }

    private var modelLine: String {
        guard let descriptor else {
            return "No model"
        }
        return "\(descriptor.displayName) · \(ModelFormatting.backendTitle(descriptor.backend))"
    }

    @MainActor
    private func refreshProfileLoop() async {
        while !Task.isCancelled {
            profile = DeviceProfileCollector().currentProfile()
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}

private struct ChatSkillSelectionSheet: View {
    let sessionID: SessionID
    let skillStore: DemoPromptSkillStore

    @Environment(\.dismiss) private var dismiss
    @State private var selection: DemoPromptSkillSelection

    init(sessionID: SessionID, skillStore: DemoPromptSkillStore) {
        self.sessionID = sessionID
        self.skillStore = skillStore
        self._selection = State(initialValue: skillStore.selection(for: sessionID))
    }

    var body: some View {
        NavigationStack {
            Form {
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
            }
            .navigationTitle("Chat Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onDisappear(perform: save)
        }
        .presentationDetents([.medium, .large])
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

    private func save() {
        skillStore.setSelection(selection, for: sessionID)
    }
}
