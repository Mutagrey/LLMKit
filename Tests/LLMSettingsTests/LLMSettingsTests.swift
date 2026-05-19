import Foundation
import LLMCore
import LLMSettings
import Testing

@Test func runtimeSettingsDefaultsAreLocalFirstAndConservative() {
    let settings = LLMRuntimeSettings.recommended

    #expect(settings.executionMode == .preferOffline)
    #expect(settings.qualityTier == .balanced)
    #expect(settings.privacyMode == .localOnly)
    #expect(settings.contextWindowTokens == 8_192)
    #expect(settings.maxOutputTokens == 512)
    #expect(settings.mlxCacheLimitMB == 128)
    #expect(settings.mlxKVBits == 4)
    #expect(settings.ggufContextFollowsRequest)
    #expect(settings.ggufUseMMap)
    #expect(settings.ggufGPUOffloadPolicy == .automatic)
    #expect(settings.ggufKVCachePolicy == .runtimeDefault)
}

@Test func normalizerClampsToPackageAndModelContextCaps() {
    let settings = LLMRuntimeSettings(
        contextWindowTokens: 131_072,
        maxOutputTokens: 16_384,
        mlxMaxKVSizeTokens: 131_072,
        ggufContextWindowTokens: 131_072,
        ggufBatchSize: 8_192
    )

    let normalized = LLMSettingsNormalizer().normalized(
        settings,
        selectedModelContextWindowTokens: 12_288
    )

    #expect(normalized.contextWindowTokens == 12_288)
    #expect(normalized.maxOutputTokens == 4_096)
    #expect(normalized.mlxMaxKVSizeTokens == 12_288)
    #expect(normalized.ggufContextWindowTokens == 12_288)
    #expect(normalized.ggufBatchSize == 1_024)
}

@Test func effectiveSettingsApplyLowMemoryClamp() {
    let settings = LLMRuntimeSettings(contextWindowTokens: 32_768, maxOutputTokens: 2_048)

    let effective = LLMSettingsNormalizer().effectiveSettings(
        for: settings,
        selectedModelContextWindowTokens: 32_768,
        isLowMemoryConstrained: true
    )

    #expect(effective.inputTokens == 8_192)
    #expect(effective.outputTokens == 512)
}

@Test func sectionResetsOnlyAffectTheirOwnGroup() {
    var settings = LLMSettingsPreset.performance.settings
    settings.executionMode = .remoteAllowed

    settings.resetGeneration()

    #expect(settings.contextWindowTokens == 8_192)
    #expect(settings.maxOutputTokens == 512)
    #expect(settings.executionMode == .remoteAllowed)
    #expect(settings.mlxCacheLimitMB == 256)
}

@Test func settingsPersistenceRoundTripsCodableValue() {
    let defaults = UserDefaults(suiteName: "LLMSettingsTests-\(UUID().uuidString)")!
    let key = "settings"
    let settings = LLMSettingsPreset.memorySaving.settings

    LLMRuntimeSettingsPersistence.save(settings, to: defaults, key: key)
    let loaded = LLMRuntimeSettingsPersistence.load(from: defaults, key: key)

    #expect(loaded == settings)
}
