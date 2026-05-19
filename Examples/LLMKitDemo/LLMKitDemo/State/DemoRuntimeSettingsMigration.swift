import Foundation
import LLMCore
import LLMSettings

enum DemoRuntimeSettingsMigration {
    static let settingsKey = "llmkit.demo.runtimeSettings.v1"
    static let selectedModelIDKey = "llmkit.demo.selectedModelID"
    static let executionModeKey = "llmkit.demo.executionMode"
    static let qualityTierKey = "llmkit.demo.qualityTier"
    static let privacyModeKey = "llmkit.demo.privacyMode"
    static let maxOutputTokensKey = "llmkit.demo.maxOutputTokens"

    private static let normalizer = LLMSettingsNormalizer()

    static func load(from defaults: UserDefaults) -> LLMRuntimeSettings {
        if defaults.data(forKey: settingsKey) != nil {
            return normalizer.normalized(LLMRuntimeSettingsPersistence.load(from: defaults, key: settingsKey))
        }

        var settings = LLMRuntimeSettings.recommended
        settings.preferredModelID = defaults.string(forKey: selectedModelIDKey).map(ModelID.init(rawValue:))
        settings.executionMode = persistedExecutionMode(from: defaults)
        settings.qualityTier = persistedQualityTier(from: defaults)
        settings.privacyMode = persistedPrivacyMode(from: defaults)
        settings.maxOutputTokens = persistedMaxOutputTokens(from: defaults)
        settings = normalizer.normalized(settings)
        LLMRuntimeSettingsPersistence.save(settings, to: defaults, key: settingsKey)
        return settings
    }

    private static func persistedExecutionMode(from defaults: UserDefaults) -> ExecutionMode {
        guard let rawValue = defaults.string(forKey: executionModeKey),
              let mode = ExecutionMode(rawValue: rawValue) else {
            return .preferOffline
        }
        return mode
    }

    private static func persistedQualityTier(from defaults: UserDefaults) -> QualityTier {
        guard let rawValue = defaults.string(forKey: qualityTierKey),
              let tier = QualityTier(rawValue: rawValue) else {
            return .balanced
        }
        return tier
    }

    private static func persistedPrivacyMode(from defaults: UserDefaults) -> PrivacyMode {
        guard let rawValue = defaults.string(forKey: privacyModeKey),
              let mode = PrivacyMode(rawValue: rawValue) else {
            return .localOnly
        }
        return mode
    }

    private static func persistedMaxOutputTokens(from defaults: UserDefaults) -> Int {
        let storedValue = defaults.object(forKey: maxOutputTokensKey) as? Int ?? 512
        return max(128, min(storedValue, 4_096))
    }
}
