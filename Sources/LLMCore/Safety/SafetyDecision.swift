import Foundation

public enum SafetyAction: Hashable, Codable, Sendable {
    case allow
    case deny(reason: String)
    case modify(reason: String)
}

public struct SafetyDecision: Hashable, Codable, Sendable {
    public let action: SafetyAction
    public let redactedText: String?

    public init(action: SafetyAction, redactedText: String? = nil) {
        self.action = action
        self.redactedText = redactedText
    }

    public static let allow = SafetyDecision(action: .allow)
}

public struct SafetyInputRequest: Hashable, Codable, Sendable {
    public let text: String
    public let requirements: ExecutionRequirements

    public init(text: String, requirements: ExecutionRequirements = ExecutionRequirements()) {
        self.text = text
        self.requirements = requirements
    }
}

public struct SafetyOutputRequest: Hashable, Codable, Sendable {
    public let text: String
    public let modelID: ModelID?

    public init(text: String, modelID: ModelID? = nil) {
        self.text = text
        self.modelID = modelID
    }
}
