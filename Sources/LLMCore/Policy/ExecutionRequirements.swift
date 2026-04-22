import Foundation

public struct ExecutionRequirements: Hashable, Codable, Sendable {
    public let requiredCapabilities: Set<ModelCapability>
    public let executionMode: ExecutionMode
    public let preferredLatency: PreferredLatency
    public let qualityTier: QualityTier
    public let preferredModel: ModelID?
    public let privacyMode: PrivacyMode
    public let budget: ExecutionBudget?

    public init(
        requiredCapabilities: Set<ModelCapability> = [],
        executionMode: ExecutionMode = .hybrid,
        preferredLatency: PreferredLatency = .interactive,
        qualityTier: QualityTier = .balanced,
        preferredModel: ModelID? = nil,
        privacyMode: PrivacyMode = .standard,
        budget: ExecutionBudget? = nil
    ) {
        self.requiredCapabilities = requiredCapabilities
        self.executionMode = executionMode
        self.preferredLatency = preferredLatency
        self.qualityTier = qualityTier
        self.preferredModel = preferredModel
        self.privacyMode = privacyMode
        self.budget = budget
    }
}

public enum ExecutionMode: String, Hashable, Codable, Sendable {
    case offlineOnly
    case preferOffline
    case hybrid
    case remoteAllowed
}

public enum PreferredLatency: String, Hashable, Codable, Sendable {
    case interactive
    case background
    case relaxed
}

public enum QualityTier: String, Hashable, Codable, Sendable {
    case fast
    case balanced
    case best
}

public enum PrivacyMode: String, Hashable, Codable, Sendable {
    case standard
    case localOnly
    case redactSensitive
}

public struct ExecutionBudget: Hashable, Codable, Sendable {
    public let maxInputTokens: Int?
    public let maxOutputTokens: Int?
    public let maxCostCents: Int?

    public init(maxInputTokens: Int? = nil, maxOutputTokens: Int? = nil, maxCostCents: Int? = nil) {
        self.maxInputTokens = maxInputTokens
        self.maxOutputTokens = maxOutputTokens
        self.maxCostCents = maxCostCents
    }
}
