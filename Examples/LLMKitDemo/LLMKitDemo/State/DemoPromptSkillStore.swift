import Foundation
import LLMCore
import Observation

@MainActor
@Observable
final class DemoPromptSkillStore {
    private(set) var skills: [DemoPromptSkill]
    private(set) var defaultSelection: DemoPromptSkillSelection
    private(set) var sessionSelections: [String: DemoPromptSkillSelection]
    private(set) var lastErrorMessage: String?

    @ObservationIgnored
    private let storageURL: URL

    @ObservationIgnored
    private let encoder: JSONEncoder

    @ObservationIgnored
    private let decoder: JSONDecoder

    init(
        storageURL: URL = DemoPromptSkillStore.defaultStorageURL(),
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.storageURL = storageURL
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.skills = []
        self.defaultSelection = DemoPromptSkillSelection(mainSkillID: Self.systemSkillID)
        self.sessionSelections = [:]
        self.lastErrorMessage = nil
        load()
    }

    func selection(for sessionID: SessionID) -> DemoPromptSkillSelection {
        (sessionSelections[sessionID.rawValue] ?? defaultSelection).normalized(availableSkills: skills)
    }

    func setDefaultSelection(_ selection: DemoPromptSkillSelection) {
        defaultSelection = selection.normalized(availableSkills: skills)
        save()
    }

    func setSelection(_ selection: DemoPromptSkillSelection, for sessionID: SessionID) {
        sessionSelections[sessionID.rawValue] = selection.normalized(availableSkills: skills)
        save()
    }

    func removeSelection(for sessionID: SessionID) {
        sessionSelections[sessionID.rawValue] = nil
        save()
    }

    func transientMessages(for sessionID: SessionID) -> [ChatMessage] {
        guard let message = DemoPromptSkillComposer.systemMessage(
            selection: selection(for: sessionID),
            skills: skills
        ) else {
            return []
        }
        return [message]
    }

    func transientSignature(for sessionID: SessionID) -> String? {
        let signature = DemoPromptSkillComposer.signature(
            selection: selection(for: sessionID),
            skills: skills
        )
        return signature.isEmpty ? nil : signature
    }

    func skill(id: UUID) -> DemoPromptSkill? {
        skills.first { $0.id == id }
    }

    func selectedSkillTitles(for selection: DemoPromptSkillSelection) -> String {
        let titles = DemoPromptSkillComposer
            .orderedSkills(selection: selection, skills: skills)
            .map(\.title)
        return titles.isEmpty ? "No skills" : titles.joined(separator: ", ")
    }

    @discardableResult
    func saveSkill(id: UUID?, title: String, prompt: String) -> DemoPromptSkill? {
        let resolvedTitle = normalizedTitle(title)
        if let id, let index = skills.firstIndex(where: { $0.id == id }) {
            skills[index].title = resolvedTitle
            skills[index].prompt = prompt
            skills[index].updatedAt = Date()
            save()
            return skills[index]
        }

        let now = Date()
        let skill = DemoPromptSkill(
            title: resolvedTitle,
            prompt: prompt,
            createdAt: now,
            updatedAt: now
        )
        skills.append(skill)
        save()
        return skill
    }

    @discardableResult
    func duplicateSkill(id: UUID) -> DemoPromptSkill? {
        guard let original = skill(id: id) else {
            return nil
        }
        let now = Date()
        let duplicate = DemoPromptSkill(
            title: "\(original.title) Copy",
            prompt: original.prompt,
            createdAt: now,
            updatedAt: now
        )
        skills.append(duplicate)
        save()
        return duplicate
    }

    @discardableResult
    func mergeSkills(ids: Set<UUID>) -> DemoPromptSkill? {
        let selectedSkills = skills.filter { ids.contains($0.id) }
        guard selectedSkills.count > 1 else {
            return nil
        }

        let prompt = selectedSkills
            .map { "## \($0.title)\n\($0.prompt.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n\n")
        return saveSkill(id: nil, title: "Merged Skill", prompt: prompt)
    }

    func deleteSkill(id: UUID) {
        guard let skill = skill(id: id), !skill.isRequiredSystemSkill else {
            return
        }
        skills.removeAll { $0.id == id }
        normalizeSelections()
        save()
    }

    func makeSelection(
        _ selection: DemoPromptSkillSelection,
        mainSkillID: UUID
    ) -> DemoPromptSkillSelection {
        DemoPromptSkillSelection(
            mainSkillID: mainSkillID,
            includedSkillIDs: selection.includedSkillIDs.filter { $0 != mainSkillID }
        )
        .normalized(availableSkills: skills)
    }

    func makeSelection(
        _ selection: DemoPromptSkillSelection,
        togglingIncludedSkillID skillID: UUID
    ) -> DemoPromptSkillSelection {
        var includedIDs = selection.includedSkillIDs
        if includedIDs.contains(skillID) {
            includedIDs.removeAll { $0 == skillID }
        } else if skillID != selection.mainSkillID {
            includedIDs.append(skillID)
        }

        return DemoPromptSkillSelection(
            mainSkillID: selection.mainSkillID,
            includedSkillIDs: includedIDs
        )
        .normalized(availableSkills: skills)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            seedDefaults()
            save()
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let persisted = try decoder.decode(PersistedState.self, from: data)
            skills = persisted.skills
            defaultSelection = persisted.defaultSelection
            sessionSelections = persisted.sessionSelections
            normalizeStateAfterLoad()
        } catch {
            lastErrorMessage = "Could not load skills: \(error.localizedDescription)"
            seedDefaults()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let persisted = PersistedState(
                skills: skills,
                defaultSelection: defaultSelection,
                sessionSelections: sessionSelections
            )
            try encoder.encode(persisted).write(to: storageURL, options: [.atomic])
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Could not save skills: \(error.localizedDescription)"
        }
    }

    private func normalizeStateAfterLoad() {
        if skills.isEmpty {
            seedDefaults()
        } else if !skills.contains(where: \.isRequiredSystemSkill) {
            skills.insert(Self.seededSkills[0], at: 0)
        }
        normalizeSelections()
        save()
    }

    private func normalizeSelections() {
        defaultSelection = defaultSelection.normalized(availableSkills: skills)
        sessionSelections = sessionSelections.mapValues { selection in
            selection.normalized(availableSkills: skills)
        }
    }

    private func seedDefaults() {
        skills = Self.seededSkills
        defaultSelection = DemoPromptSkillSelection(mainSkillID: Self.systemSkillID)
        sessionSelections = [:]
    }

    private func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Skill" : trimmed
    }

    static func defaultStorageURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return root
            .appendingPathComponent("LLMKit", isDirectory: true)
            .appendingPathComponent("DemoSkills", isDirectory: true)
            .appendingPathComponent("skills.json")
    }
}

extension DemoPromptSkillStore: @unchecked Sendable {}

private struct PersistedState: Codable {
    var schemaVersion = 1
    var skills: [DemoPromptSkill]
    var defaultSelection: DemoPromptSkillSelection
    var sessionSelections: [String: DemoPromptSkillSelection]
}

private extension DemoPromptSkillStore {
    static let systemSkillID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

    static let seededSkills: [DemoPromptSkill] = [
        DemoPromptSkill(
            id: systemSkillID,
            title: "System",
            prompt: """
            You are a helpful assistant inside the LLMKit demo app.

            Be accurate, concise, and explicit about uncertainty. Follow the user's language unless they ask otherwise. Do not claim access to app state, private data, tools, or files unless that context is explicitly provided in the conversation.
            """,
            isRequiredSystemSkill: true
        ),
        DemoPromptSkill(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            title: "Concise Answers",
            prompt: "Prefer short, direct answers. Use bullets only when they improve scanability."
        ),
        DemoPromptSkill(
            id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
            title: "Swift / iOS Engineer",
            prompt: "Answer as a senior Swift and Apple-platform engineer. Prefer Swift concurrency, SwiftUI-native state, focused types, and clear module boundaries."
        ),
        DemoPromptSkill(
            id: UUID(uuidString: "44444444-4444-4444-8444-444444444444")!,
            title: "Code Review",
            prompt: "Review code by leading with concrete bugs, regressions, architecture risks, and missing tests. Keep summaries secondary."
        ),
        DemoPromptSkill(
            id: UUID(uuidString: "55555555-5555-4555-8555-555555555555")!,
            title: "Russian Replies",
            prompt: "Reply in Russian unless the user explicitly asks for another language. Keep the style concise and practical."
        )
    ]
}
