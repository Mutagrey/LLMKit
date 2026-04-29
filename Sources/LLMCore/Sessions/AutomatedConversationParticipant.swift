import Foundation

public struct AutomatedConversationParticipant: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let role: String
    public let instructions: String
    public let selectionPolicy: ModelSelectionPolicy?

    public init(
        id: String,
        displayName: String,
        role: String,
        instructions: String = "",
        selectionPolicy: ModelSelectionPolicy? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.instructions = instructions
        self.selectionPolicy = selectionPolicy
    }
}
