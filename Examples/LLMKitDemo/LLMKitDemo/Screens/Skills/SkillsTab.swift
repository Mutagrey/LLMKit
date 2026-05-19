import SwiftUI

struct SkillsTab: View {
    let store: DemoPromptSkillStore

    @State private var presentedEditor: SkillEditorRoute?
    @State private var selectedSkillIDs = Set<UUID>()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SkillsList(
                    store: store,
                    selectedSkillIDs: $selectedSkillIDs,
                    editSkill: { presentedEditor = .edit($0.id) },
                    useAsMain: { useAsMain($0) },
                    toggleDefaultInclusion: { toggleDefaultInclusion($0) },
                    duplicate: { duplicate($0) },
                    delete: { delete($0) }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Skills")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if selectedSkillIDs.count > 1 {
                            Button {
                                mergeSelectedSkills()
                            } label: {
                                Image(systemName: "arrow.triangle.merge")
                            }
                            .accessibilityLabel("Merge selected skills")
                        }

                        Button {
                            presentedEditor = .new
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("New skill")
                    }
                }
                .sheet(item: $presentedEditor) { route in
                    NavigationStack {
                        SkillEditorView(store: store, route: route)
                    }
                }
        }
    }

    private func useAsMain(_ skill: DemoPromptSkill) {
        store.setDefaultSelection(
            store.makeSelection(store.defaultSelection, mainSkillID: skill.id)
        )
    }

    private func toggleDefaultInclusion(_ skill: DemoPromptSkill) {
        store.setDefaultSelection(
            store.makeSelection(store.defaultSelection, togglingIncludedSkillID: skill.id)
        )
    }

    private func duplicate(_ skill: DemoPromptSkill) {
        guard let duplicate = store.duplicateSkill(id: skill.id) else {
            return
        }
        presentedEditor = .edit(duplicate.id)
    }

    private func delete(_ skill: DemoPromptSkill) {
        store.deleteSkill(id: skill.id)
        selectedSkillIDs.remove(skill.id)
    }

    private func mergeSelectedSkills() {
        guard let merged = store.mergeSkills(ids: selectedSkillIDs) else {
            return
        }
        selectedSkillIDs.removeAll()
        presentedEditor = .edit(merged.id)
    }
}

private struct SkillsList: View {
    let store: DemoPromptSkillStore
    @Binding var selectedSkillIDs: Set<UUID>
    let editSkill: (DemoPromptSkill) -> Void
    let useAsMain: (DemoPromptSkill) -> Void
    let toggleDefaultInclusion: (DemoPromptSkill) -> Void
    let duplicate: (DemoPromptSkill) -> Void
    let delete: (DemoPromptSkill) -> Void

    @Environment(\.editMode) private var editMode

    var body: some View {
        Group {
            if isEditing {
                List(selection: $selectedSkillIDs) {
                    defaultCombinationSection
                    skillsSection
                }
            } else {
                List {
                    defaultCombinationSection
                    skillsSection
                }
            }
        }
        .id(isEditing)
        .onChange(of: isEditing) { _, isEditing in
            if !isEditing {
                selectedSkillIDs.removeAll()
            }
        }
    }

    private var defaultCombinationSection: some View {
        Section("Default Combination") {
            LabeledContent("Main", value: defaultMainTitle)
            Text(store.selectedSkillTitles(for: store.defaultSelection))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private var skillsSection: some View {
        Section("Skills") {
            ForEach(store.skills) { skill in
                skillListRow(for: skill)
            }
        }
    }

    @ViewBuilder
    private func skillListRow(for skill: DemoPromptSkill) -> some View {
        if isEditing {
            SkillRow(
                skill: skill,
                isMain: store.defaultSelection.mainSkillID == skill.id,
                isIncluded: store.defaultSelection.includedSkillIDs.contains(skill.id),
                isEditing: true,
                edit: {}
            )
            .tag(skill.id)
            .contextMenu {
                skillActions(for: skill)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                leadingSwipeActions(for: skill)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                trailingSwipeActions(for: skill)
            }
        } else {
            SkillRow(
                skill: skill,
                isMain: store.defaultSelection.mainSkillID == skill.id,
                isIncluded: store.defaultSelection.includedSkillIDs.contains(skill.id),
                isEditing: false,
                edit: {
                    editSkill(skill)
                }
            )
            .contextMenu {
                skillActions(for: skill)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                leadingSwipeActions(for: skill)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                trailingSwipeActions(for: skill)
            }
        }
    }

    @ViewBuilder
    private func skillActions(for skill: DemoPromptSkill) -> some View {
        Button {
            editSkill(skill)
        } label: {
            Label("Edit", systemImage: "square.and.pencil")
        }

        Button {
            useAsMain(skill)
        } label: {
            Label("Use as Main", systemImage: "star.fill")
        }

        Button {
            toggleDefaultInclusion(skill)
        } label: {
            Label(
                store.defaultSelection.includedSkillIDs.contains(skill.id) ? "Remove from Default" : "Include in Default",
                systemImage: "checkmark.circle"
            )
        }
        .disabled(store.defaultSelection.mainSkillID == skill.id)

        Button {
            duplicate(skill)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Button(role: .destructive) {
            delete(skill)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(skill.isRequiredSystemSkill)
    }

    @ViewBuilder
    private func leadingSwipeActions(for skill: DemoPromptSkill) -> some View {
        Button {
            useAsMain(skill)
        } label: {
            Label("Main", systemImage: "star.fill")
        }
        .tint(.blue)

        Button {
            toggleDefaultInclusion(skill)
        } label: {
            Label(
                store.defaultSelection.includedSkillIDs.contains(skill.id) ? "Remove" : "Include",
                systemImage: "checkmark.circle"
            )
        }
        .tint(.green)
        .disabled(store.defaultSelection.mainSkillID == skill.id)
    }

    @ViewBuilder
    private func trailingSwipeActions(for skill: DemoPromptSkill) -> some View {
        Button(role: .destructive) {
            delete(skill)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(skill.isRequiredSystemSkill)

        Button {
            duplicate(skill)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        .tint(.orange)
    }

    private var defaultMainTitle: String {
        store.skill(id: store.defaultSelection.mainSkillID)?.title ?? "Missing"
    }

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }
}

private struct SkillRow: View {
    let skill: DemoPromptSkill
    let isMain: Bool
    let isIncluded: Bool
    let isEditing: Bool
    let edit: () -> Void

    var body: some View {
        if isEditing {
            content
        } else {
            Button(action: edit) {
                content
            }
            .buttonStyle(.plain)
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(skill.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isMain {
                        Label("Main", systemImage: "star.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.blue)
                    } else if isIncluded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Text(skill.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if skill.isRequiredSystemSkill {
                Text("Required")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private enum SkillEditorRoute: Identifiable, Hashable {
    case new
    case edit(UUID)

    var id: String {
        switch self {
        case .new:
            "new"
        case .edit(let id):
            id.uuidString
        }
    }

    var skillID: UUID? {
        switch self {
        case .new:
            nil
        case .edit(let id):
            id
        }
    }
}

private struct SkillEditorView: View {
    enum Field {
        case title
        case prompt
    }

    let store: DemoPromptSkillStore
    let route: SkillEditorRoute

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var prompt: String
    @State private var didCancel = false
    @State private var didSave = false
    @FocusState private var focusedField: Field?

    init(store: DemoPromptSkillStore, route: SkillEditorRoute) {
        self.store = store
        self.route = route
        let skill = route.skillID.flatMap(store.skill(id:))
        self._title = State(initialValue: skill?.title ?? "")
        self._prompt = State(initialValue: skill?.prompt ?? "")
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Skill name", text: $title)
                    .focused($focusedField, equals: .title)
                    .textInputAutocapitalization(.words)
            }

            Section("Prompt") {
                TextEditor(text: $prompt)
                    .font(.callout.monospaced())
                    .frame(minHeight: 300)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .prompt)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(false)
        .navigationTitle(route.skillID == nil ? "New Skill" : "Edit Skill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    didCancel = true
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    saveIfNeeded()
                    dismiss()
                }
                .fontWeight(.semibold)
            }

            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
        .onDisappear {
            saveIfNeeded()
        }
    }

    private func saveIfNeeded() {
        guard !didCancel, !didSave else {
            return
        }
        if route.skillID == nil,
           title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            didSave = true
            return
        }
        store.saveSkill(id: route.skillID, title: title, prompt: prompt)
        didSave = true
    }
}
