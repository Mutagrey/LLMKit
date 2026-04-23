import LLMCore

#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
import FoundationModels
#endif

enum FoundationModelsGenerationOptionsMapper {
    #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    static func options(for requirements: ExecutionRequirements) -> GenerationOptions {
        GenerationOptions(
            sampling: samplingMode(for: requirements.qualityTier),
            temperature: temperature(for: requirements.qualityTier),
            maximumResponseTokens: requirements.budget?.maxOutputTokens
        )
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func samplingMode(for qualityTier: QualityTier) -> GenerationOptions.SamplingMode? {
        switch qualityTier {
        case .fast:
            return .greedy
        case .balanced, .best:
            return nil
        }
    }

    private static func temperature(for qualityTier: QualityTier) -> Double? {
        switch qualityTier {
        case .fast:
            return 0.0
        case .balanced:
            return 0.7
        case .best:
            return 0.9
        }
    }
    #endif
}
