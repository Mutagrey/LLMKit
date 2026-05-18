import Foundation
import LLMCore
import LLMProtocols

#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
import FoundationModels
#endif

protocol FoundationModelsRuntime: Sendable {
    func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<String, Error>
    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<String, Error>
}

struct FoundationModelsNativeRuntime: FoundationModelsRuntime {
    func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.generate(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.chat(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private static func generate(
        _ request: BackendGenerationRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = try defaultModel()
            let session = LanguageModelSession(model: model)
            let options = FoundationModelsGenerationOptionsMapper.options(for: request.request.requirements)

            if
                let structuredOutputSchema = request.request.structuredOutputSchema,
                let mappedSchema = try? FoundationModelsStructuredOutputMapper.generationSchema(for: structuredOutputSchema)
            {
                let response = try await session.respond(
                    to: request.request.prompt,
                    schema: mappedSchema,
                    includeSchemaInPrompt: false,
                    options: options
                )
                if !response.content.jsonString.isEmpty {
                    continuation.yield(response.content.jsonString)
                }
            } else {
                var reducer = FoundationModelsStreamDeltaReducer()
                let stream = session.streamResponse(
                    to: request.request.renderedPrompt,
                    options: options
                )
                for try await snapshot in stream {
                    try Task.checkCancellation()
                    if let delta = reducer.delta(from: snapshot.content) {
                        continuation.yield(delta)
                    }
                }
            }
            return
        }
        #endif

        throw LLMError.unavailable
    }

    private static func chat(
        _ request: BackendChatRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = try defaultModel()
            let mappedPrompt = FoundationModelsPromptMapper.prompt(for: request.request)
            let session = LanguageModelSession(model: model, instructions: mappedPrompt.instructions)
            let stream = session.streamResponse(
                to: mappedPrompt.prompt,
                options: FoundationModelsGenerationOptionsMapper.options(for: request.request.requirements)
            )
            var reducer = FoundationModelsStreamDeltaReducer()
            for try await snapshot in stream {
                try Task.checkCancellation()
                if let delta = reducer.delta(from: snapshot.content) {
                    continuation.yield(delta)
                }
            }
            return
        }
        #endif

        throw LLMError.unavailable
    }

    #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func defaultModel() throws -> SystemLanguageModel {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw LLMError.unavailable
        }
        guard model.supportsLocale(.autoupdatingCurrent) else {
            let locale = Locale.autoupdatingCurrent
            let identifier = locale.identifier.isEmpty ? "current locale" : locale.identifier
            throw LLMError.unsupportedLocale("Apple Intelligence does not support the current locale (\(identifier)).")
        }
        return model
    }
    #endif
}

struct FoundationModelsStreamDeltaReducer: Equatable, Sendable {
    private var emittedText = ""

    mutating func delta(from cumulativeText: String) -> String? {
        guard cumulativeText.hasPrefix(emittedText) else {
            emittedText = cumulativeText
            return cumulativeText.isEmpty ? nil : cumulativeText
        }

        let deltaStart = cumulativeText.index(cumulativeText.startIndex, offsetBy: emittedText.count)
        let delta = String(cumulativeText[deltaStart...])
        emittedText = cumulativeText
        return delta.isEmpty ? nil : delta
    }
}
