import Foundation
import LLMCore
import LLMSettings

public enum LLMSettingsFormatting {
    public static func tokenCount(_ value: Int) -> String {
        "\(value.formatted()) tokens"
    }

    public static func megabytes(_ value: Int) -> String {
        "\(value.formatted()) MB"
    }

    public static func title(for mode: ExecutionMode) -> String {
        switch mode {
        case .offlineOnly:
            return "Offline Only"
        case .preferOffline:
            return "Prefer Offline"
        case .hybrid:
            return "Hybrid"
        case .remoteAllowed:
            return "Remote Allowed"
        }
    }

    public static func title(for tier: QualityTier) -> String {
        switch tier {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced"
        case .best:
            return "Best"
        }
    }

    public static func title(for mode: PrivacyMode) -> String {
        switch mode {
        case .standard:
            return "Standard"
        case .localOnly:
            return "Local Only"
        case .redactSensitive:
            return "Redact Sensitive"
        }
    }

    public static func title(for preset: LLMSettingsPreset) -> String {
        switch preset {
        case .recommended:
            return "Recommended"
        case .memorySaving:
            return "Memory Saving"
        case .performance:
            return "Performance"
        case .defaults:
            return "Defaults"
        }
    }

    public static func title(for policy: LLMGPUOffloadPolicy) -> String {
        switch policy {
        case .automatic:
            return "Automatic"
        case .disabled:
            return "Off"
        case .custom(let layerCount):
            return "\(layerCount) layers"
        }
    }

    public static func title(for policy: KVCachePolicy) -> String {
        switch policy {
        case .runtimeDefault:
            return "Runtime Default"
        case .safeF16:
            return "Safe F16"
        case .q8Experimental:
            return "Q8 Experimental"
        case .q4Experimental:
            return "Q4 Experimental"
        }
    }
}
