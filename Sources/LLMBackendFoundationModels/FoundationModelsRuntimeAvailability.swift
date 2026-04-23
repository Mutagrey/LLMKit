#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
import FoundationModels
#endif

public struct FoundationModelsRuntimeAvailability: Hashable, Sendable {
    public let isAvailable: Bool
    public let reason: String?

    public init(isAvailable: Bool, reason: String? = nil) {
        self.isAvailable = isAvailable
        self.reason = reason
    }

    public static var current: FoundationModelsRuntimeAvailability {
        FoundationModelsRuntimeProbe.currentAvailability()
    }
}

enum FoundationModelsRuntimeProbe {
    static func currentAvailability() -> FoundationModelsRuntimeAvailability {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return FoundationModelsRuntimeAvailability(isAvailable: true)
            case .unavailable(let reason):
                return FoundationModelsRuntimeAvailability(isAvailable: false, reason: unavailableReasonDescription(reason))
            }
        }
        #endif

        return FoundationModelsRuntimeAvailability(
            isAvailable: false,
            reason: "Foundation Models requires iOS 26, macOS 26, or visionOS 26."
        )
    }

    #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func unavailableReasonDescription(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device is not eligible for Apple Intelligence Foundation Models."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled."
        case .modelNotReady:
            return "The system Foundation Model is not ready on this device."
        @unknown default:
            return "Foundation Models is unavailable for an unknown reason."
        }
    }
    #endif
}
