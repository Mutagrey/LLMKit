import Foundation
import LLMCore
import LLMSettings
import Testing

@Test func demoRuntimeSettingsMigrationReadsLegacyKeysOnce() {
    let defaults = UserDefaults(suiteName: "DemoSettingsMigration-\(UUID().uuidString)")!
    defaults.set("demo/model", forKey: DemoRuntimeSettingsMigration.selectedModelIDKey)
    defaults.set(ExecutionMode.remoteAllowed.rawValue, forKey: DemoRuntimeSettingsMigration.executionModeKey)
    defaults.set(QualityTier.best.rawValue, forKey: DemoRuntimeSettingsMigration.qualityTierKey)
    defaults.set(PrivacyMode.standard.rawValue, forKey: DemoRuntimeSettingsMigration.privacyModeKey)
    defaults.set(2_048, forKey: DemoRuntimeSettingsMigration.maxOutputTokensKey)

    let settings = DemoRuntimeSettingsMigration.load(from: defaults)

    #expect(settings.preferredModelID == ModelID(rawValue: "demo/model"))
    #expect(settings.executionMode == .remoteAllowed)
    #expect(settings.qualityTier == .best)
    #expect(settings.privacyMode == .standard)
    #expect(settings.maxOutputTokens == 2_048)
    #expect(defaults.data(forKey: DemoRuntimeSettingsMigration.settingsKey) != nil)
}

@Test func demoRuntimeSettingsMigrationPrefersSharedSettingsBlob() {
    let defaults = UserDefaults(suiteName: "DemoSettingsMigration-\(UUID().uuidString)")!
    let stored = LLMSettingsPreset.memorySaving.settings
    LLMRuntimeSettingsPersistence.save(stored, to: defaults, key: DemoRuntimeSettingsMigration.settingsKey)
    defaults.set(ExecutionMode.remoteAllowed.rawValue, forKey: DemoRuntimeSettingsMigration.executionModeKey)

    let settings = DemoRuntimeSettingsMigration.load(from: defaults)

    #expect(settings == stored)
}
