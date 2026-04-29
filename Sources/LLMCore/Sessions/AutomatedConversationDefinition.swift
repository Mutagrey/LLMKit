import Foundation

public struct AutomatedConversationDefinition: Hashable, Codable, Sendable {
    public let topic: String
    public let participants: [AutomatedConversationParticipant]
    public let sharedExecutionRequirements: ExecutionRequirements?
    public let maxTurns: Int
    public let backgroundPolicy: AutomationBackgroundPolicy

    public init(
        topic: String,
        participants: [AutomatedConversationParticipant],
        sharedExecutionRequirements: ExecutionRequirements? = nil,
        maxTurns: Int,
        backgroundPolicy: AutomationBackgroundPolicy = .bestEffort
    ) {
        self.topic = topic
        self.participants = participants
        self.sharedExecutionRequirements = sharedExecutionRequirements
        self.maxTurns = maxTurns
        self.backgroundPolicy = backgroundPolicy
    }
}
