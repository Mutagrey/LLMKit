import LLMCore
import LLMSettings
import LLMUISettings
import Testing

@Test func settingsScreenConfigurationDefaultsShowEverySection() {
    let configuration = LLMSettingsScreenConfiguration()

    #expect(configuration.visibleSections == Set(LLMSettingsSection.allCases))
    #expect(configuration.allowsRoutingControls)
    #expect(configuration.showsRemoteRoutingModes)
}

@Test func settingsFormattingUsesStableTitles() {
    #expect(LLMSettingsFormatting.title(for: ExecutionMode.preferOffline) == "Prefer Offline")
    #expect(LLMSettingsFormatting.title(for: QualityTier.balanced) == "Balanced")
    #expect(LLMSettingsFormatting.title(for: PrivacyMode.localOnly) == "Local Only")
    #expect(LLMSettingsFormatting.title(for: LLMSettingsPreset.memorySaving) == "Memory Saving")
    #expect(LLMSettingsFormatting.title(for: KVCachePolicy.q4Experimental) == "Q4 Experimental")
}
