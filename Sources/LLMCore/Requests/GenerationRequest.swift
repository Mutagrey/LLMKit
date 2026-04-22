import Foundation

public struct GenerationRequest: Hashable, Codable, Sendable {
    public let prompt: String
    public let requirements: ExecutionRequirements
    public let sessionID: SessionID?

    public init(prompt: String, requirements: ExecutionRequirements = ExecutionRequirements(), sessionID: SessionID? = nil) {
        self.prompt = prompt
        self.requirements = requirements
        self.sessionID = sessionID
    }
}
