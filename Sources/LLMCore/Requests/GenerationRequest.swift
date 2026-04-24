import Foundation

public struct GenerationRequest: Hashable, Codable, Sendable {
    public let prompt: String
    public let structuredOutputSchema: StructuredOutputSchema?
    public let requirements: ExecutionRequirements
    public let sessionID: SessionID?

    public var renderedPrompt: String {
        StructuredOutputPromptRenderer.render(prompt: prompt, schema: structuredOutputSchema)
    }

    public init(
        prompt: String,
        structuredOutputSchema: StructuredOutputSchema? = nil,
        requirements: ExecutionRequirements = ExecutionRequirements(),
        sessionID: SessionID? = nil
    ) {
        self.prompt = prompt
        self.structuredOutputSchema = structuredOutputSchema
        self.requirements = requirements
        self.sessionID = sessionID
    }

    public init(prompt: String, requirements: ExecutionRequirements, sessionID: SessionID? = nil) {
        self.init(
            prompt: prompt,
            structuredOutputSchema: nil,
            requirements: requirements,
            sessionID: sessionID
        )
    }
}
