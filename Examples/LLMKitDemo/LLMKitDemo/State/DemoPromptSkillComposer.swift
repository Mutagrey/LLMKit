import Foundation
import LLMCore

enum DemoPromptSkillComposer {
    static func systemMessage(
        selection: DemoPromptSkillSelection,
        skills: [DemoPromptSkill]
    ) -> ChatMessage? {
        let prompt = systemPrompt(selection: selection, skills: skills)
        guard !prompt.isEmpty else {
            return nil
        }
        return ChatMessage(role: .system, content: MessageContent(text: prompt))
    }

    static func systemPrompt(
        selection: DemoPromptSkillSelection,
        skills: [DemoPromptSkill]
    ) -> String {
        orderedSkills(selection: selection, skills: skills)
            .compactMap(section(for:))
            .joined(separator: "\n\n")
    }

    static func signature(
        selection: DemoPromptSkillSelection,
        skills: [DemoPromptSkill]
    ) -> String {
        orderedSkills(selection: selection, skills: skills)
            .map { skill in
                [
                    skill.id.uuidString,
                    String(skill.updatedAt.timeIntervalSince1970),
                    skill.title,
                    skill.prompt
                ].joined(separator: "\u{1F}")
            }
            .joined(separator: "\u{1E}")
    }

    static func orderedSkills(
        selection: DemoPromptSkillSelection,
        skills: [DemoPromptSkill]
    ) -> [DemoPromptSkill] {
        let normalizedSelection = selection.normalized(availableSkills: skills)
        let skillsByID = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0) })
        return normalizedSelection
            .orderedSkillIDs(availableSkills: skills)
            .compactMap { skillsByID[$0] }
    }

    private static func section(for skill: DemoPromptSkill) -> String? {
        let prompt = skill.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            return nil
        }

        let title = skill.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return prompt
        }
        return "## \(title)\n\(prompt)"
    }
}
