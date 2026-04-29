import Foundation
import LLMCore
#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
import FoundationModels
#endif

public struct FoundationModelsRuntimeAvailability: Hashable, Sendable {
    public let isAvailable: Bool
    public let reason: String?
    public let failure: LLMError?

    public init(isAvailable: Bool, reason: String? = nil, failure: LLMError? = nil) {
        self.isAvailable = isAvailable
        self.reason = reason
        self.failure = failure
    }

    public static var current: FoundationModelsRuntimeAvailability {
        FoundationModelsRuntimeProbe.currentAvailability()
    }
}

enum FoundationModelsRuntimeProbe {
    static func currentAvailability() -> FoundationModelsRuntimeAvailability {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                let locale = Locale.autoupdatingCurrent
                guard model.supportsLocale(locale) else {
                    let identifier = locale.identifier.isEmpty ? "current locale" : locale.identifier
                    return FoundationModelsRuntimeAvailability(
                        isAvailable: false,
                        reason: "Apple Intelligence does not support the current locale (\(identifier)).",
                        failure: .unsupportedLocale("Apple Intelligence does not support the current locale (\(identifier)).")
                    )
                }
                return FoundationModelsRuntimeAvailability(isAvailable: true)
            case .unavailable(let reason):
                let reasonText = unavailableReasonDescription(reason)
                return FoundationModelsRuntimeAvailability(isAvailable: false, reason: reasonText, failure: .unavailable)
            }
        }
        #endif

        return FoundationModelsRuntimeAvailability(
            isAvailable: false,
            reason: "Foundation Models requires iOS 26, macOS 26, or visionOS 26.",
            failure: .unavailable
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
