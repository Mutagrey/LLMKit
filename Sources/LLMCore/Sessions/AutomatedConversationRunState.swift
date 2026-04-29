import Foundation

public enum AutomatedConversationRunPhase: String, Hashable, Codable, Sendable {
    case idle
    case running
    case paused
    case failed
    case completed
}

public enum AutomationBackgroundPolicy: String, Hashable, Codable, Sendable {
    case foregroundOnly
    case bestEffort
}

public struct AutomatedConversationRunState: Hashable, Codable, Sendable {
    public let phase: AutomatedConversationRunPhase
    public let completedTurns: Int
    public let nextParticipantIndex: Int
    public let lastErrorMessage: String?
    public let lastUpdatedAt: Date

    public init(
        phase: AutomatedConversationRunPhase = .idle,
        completedTurns: Int = 0,
        nextParticipantIndex: Int = 0,
        lastErrorMessage: String? = nil,
        lastUpdatedAt: Date = Date()
    ) {
        self.phase = phase
        self.completedTurns = completedTurns
        self.nextParticipantIndex = nextParticipantIndex
        self.lastErrorMessage = lastErrorMessage
        self.lastUpdatedAt = lastUpdatedAt
    }
}
