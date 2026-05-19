import Foundation

struct DemoPromptSkill: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var prompt: String
    var isRequiredSystemSkill: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        isRequiredSystemSkill: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.isRequiredSystemSkill = isRequiredSystemSkill
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DemoPromptSkillSelection: Hashable, Codable, Sendable {
    var mainSkillID: UUID
    var includedSkillIDs: [UUID]

    init(mainSkillID: UUID, includedSkillIDs: [UUID] = []) {
        self.mainSkillID = mainSkillID
        self.includedSkillIDs = includedSkillIDs
    }

    func orderedSkillIDs(availableSkills: [DemoPromptSkill]) -> [UUID] {
        let availableIDs = Set(availableSkills.map(\.id))
        guard availableIDs.contains(mainSkillID) else {
            return normalized(availableSkills: availableSkills).orderedSkillIDs(availableSkills: availableSkills)
        }

        var result = [mainSkillID]
        for id in includedSkillIDs where availableIDs.contains(id) && id != mainSkillID && !result.contains(id) {
            result.append(id)
        }
        return result
    }

    func normalized(availableSkills: [DemoPromptSkill]) -> DemoPromptSkillSelection {
        guard !availableSkills.isEmpty else {
            return self
        }

        let availableIDs = Set(availableSkills.map(\.id))
        let fallbackMainID = availableSkills.first(where: \.isRequiredSystemSkill)?.id ?? availableSkills[0].id
        let normalizedMainID = availableIDs.contains(mainSkillID) ? mainSkillID : fallbackMainID
        let normalizedIncludedIDs = includedSkillIDs.reduce(into: [UUID]()) { partialResult, id in
            guard availableIDs.contains(id), id != normalizedMainID, !partialResult.contains(id) else {
                return
            }
            partialResult.append(id)
        }

        return DemoPromptSkillSelection(
            mainSkillID: normalizedMainID,
            includedSkillIDs: normalizedIncludedIDs
        )
    }
}
