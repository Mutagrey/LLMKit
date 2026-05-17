import Foundation

public struct StructuredRequest: Hashable, Codable, Sendable {
    public let prompt: String
    public let schema: StructuredOutputSchema?
    public let requirements: ExecutionRequirements
    public let sessionID: SessionID?

    public var schemaName: String? {
        schema?.name
    }

    public var renderedPrompt: String {
        StructuredOutputPromptRenderer.render(prompt: prompt, schema: schema)
    }

    public init(
        prompt: String,
        schema: StructuredOutputSchema? = nil,
        requirements: ExecutionRequirements = ExecutionRequirements(requiredCapabilities: [.completion]),
        sessionID: SessionID? = nil
    ) {
        self.prompt = prompt
        self.schema = schema
        self.requirements = requirements
        self.sessionID = sessionID
    }
}
