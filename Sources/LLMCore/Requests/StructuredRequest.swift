import Foundation

public struct StructuredRequest: Hashable, Codable, Sendable {
    public let prompt: String
    public let schemaName: String?
    public let requirements: ExecutionRequirements
    public let sessionID: SessionID?

    public init(
        prompt: String,
        schemaName: String? = nil,
        requirements: ExecutionRequirements = ExecutionRequirements(requiredCapabilities: [.structuredOutput]),
        sessionID: SessionID? = nil
    ) {
        self.prompt = prompt
        self.schemaName = schemaName
        self.requirements = requirements
        self.sessionID = sessionID
    }
}
