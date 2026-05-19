import Foundation
import LLMCore
import Testing

@Test func demoPromptSkillComposerOrdersMainSkillBeforeIncludedSkills() throws {
    let main = DemoPromptSkill(title: "Main", prompt: "Main prompt")
    let first = DemoPromptSkill(title: "First", prompt: "First prompt")
    let second = DemoPromptSkill(title: "Second", prompt: "Second prompt")
    let selection = DemoPromptSkillSelection(
        mainSkillID: main.id,
        includedSkillIDs: [second.id, first.id]
    )

    let prompt = DemoPromptSkillComposer.systemPrompt(
        selection: selection,
        skills: [first, main, second]
    )

    let mainIndex = try #require(prompt.range(of: "## Main")?.lowerBound)
    let secondIndex = try #require(prompt.range(of: "## Second")?.lowerBound)
    let firstIndex = try #require(prompt.range(of: "## First")?.lowerBound)

    #expect(mainIndex == prompt.startIndex)
    #expect(secondIndex < firstIndex)
}

@MainActor
@Test func demoPromptSkillStoreSeedsDefaultsAndPreservesEdits() throws {
    let storageURL = temporarySkillStoreURL()
    let firstStore = DemoPromptSkillStore(storageURL: storageURL)

    let systemSkill = try #require(firstStore.skills.first { $0.isRequiredSystemSkill })
    #expect(systemSkill.title == "System")
    #expect(firstStore.skills.count >= 5)

    let updated = firstStore.saveSkill(
        id: systemSkill.id,
        title: "Custom System",
        prompt: "Custom prompt"
    )
    #expect(updated?.title == "Custom System")

    let secondStore = DemoPromptSkillStore(storageURL: storageURL)
    let reloaded = secondStore.skills.first { $0.id == updated?.id }

    #expect(reloaded?.title == "Custom System")
    #expect(reloaded?.prompt == "Custom prompt")
}

@MainActor
@Test func demoPromptSkillStorePersistsSessionSelection() throws {
    let storageURL = temporarySkillStoreURL()
    let store = DemoPromptSkillStore(storageURL: storageURL)
    let systemSkill = try #require(store.skills.first { $0.isRequiredSystemSkill })
    let auxiliarySkill = try #require(store.skills.first { !$0.isRequiredSystemSkill })
    let sessionID = SessionID(rawValue: "session-for-skills")
    let selection = DemoPromptSkillSelection(
        mainSkillID: systemSkill.id,
        includedSkillIDs: [auxiliarySkill.id]
    )

    store.setSelection(selection, for: sessionID)

    let reloaded = DemoPromptSkillStore(storageURL: storageURL)
    #expect(reloaded.selection(for: sessionID).includedSkillIDs == [auxiliarySkill.id])
}

private func temporarySkillStoreURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("skills.json")
}
