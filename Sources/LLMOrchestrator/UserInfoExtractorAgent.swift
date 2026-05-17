import LLMCore
import LLMProtocols

public struct UserInfoExtractorAgent: Sendable {
    public let sessionID: SessionID
    private let structured: any StructuredGenerationService
    private let requirements: ExecutionRequirements

    public init(
        structured: any StructuredGenerationService,
        sessionID: SessionID = .generated(),
        requirements: ExecutionRequirements = ExecutionRequirements(
            requiredCapabilities: [.completion],
            executionMode: .offlineOnly,
            preferredLatency: .background,
            privacyMode: .localOnly,
            budget: ExecutionBudget(maxOutputTokens: 512)
        )
    ) {
        self.structured = structured
        self.sessionID = sessionID
        self.requirements = requirements
    }

    public func extract<T: Decodable & Sendable>(
        _ type: T.Type,
        from text: String,
        schema: StructuredOutputSchema,
        existingUserContext: String? = nil
    ) async throws -> T {
        try await structured.generate(
            type,
            request: StructuredRequest(
                prompt: prompt(text: text, existingUserContext: existingUserContext),
                schema: schema,
                requirements: requirements,
                sessionID: sessionID
            )
        )
    }

    private func prompt(text: String, existingUserContext: String?) -> String {
        let context = existingUserContext?.isEmpty == false ? existingUserContext ?? "None." : "None."
        return [
            "Extract durable, useful user facts from the input.",
            "Ignore transient CGM readings unless they reveal a stable preference, routine, constraint, or health-management context.",
            "Existing user context:",
            context,
            "Input:",
            text
        ].joined(separator: "\n\n")
    }
}
