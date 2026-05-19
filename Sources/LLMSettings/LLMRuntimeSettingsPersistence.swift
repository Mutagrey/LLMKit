import Foundation

public enum LLMRuntimeSettingsPersistence {
    public static func load(
        from defaults: UserDefaults,
        key: String,
        fallback: LLMRuntimeSettings = .recommended
    ) -> LLMRuntimeSettings {
        guard let data = defaults.data(forKey: key) else {
            return fallback
        }
        return (try? JSONDecoder().decode(LLMRuntimeSettings.self, from: data)) ?? fallback
    }

    public static func save(_ settings: LLMRuntimeSettings, to defaults: UserDefaults, key: String) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
