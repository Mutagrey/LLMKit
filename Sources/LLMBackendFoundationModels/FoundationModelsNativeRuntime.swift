import LLMCore
import LLMProtocols

#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
import FoundationModels
#endif

enum FoundationModelsNativeRuntime {
    static func generate(_ request: BackendGenerationRequest) async throws -> String {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw LLMError.unavailable
            }

            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: request.request.renderedPrompt,
                options: FoundationModelsGenerationOptionsMapper.options(for: request.request.requirements)
            )
            return response.content
        }
        #endif

        throw LLMError.unavailable
    }

    static func chat(_ request: BackendChatRequest) async throws -> String {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw LLMError.unavailable
            }

            let mappedPrompt = FoundationModelsPromptMapper.prompt(for: request.request)
            let session = LanguageModelSession(model: model, instructions: mappedPrompt.instructions)
            let response = try await session.respond(
                to: mappedPrompt.prompt,
                options: FoundationModelsGenerationOptionsMapper.options(for: request.request.requirements)
            )
            return response.content
        }
        #endif

        throw LLMError.unavailable
    }
}
