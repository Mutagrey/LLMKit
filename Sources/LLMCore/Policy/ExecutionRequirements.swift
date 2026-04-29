import Foundation

public struct ExecutionRequirements: Hashable, Codable, Sendable {
    public let requiredCapabilities: Set<ModelCapability>
    public let selectionPolicy: ModelSelectionPolicy
    public let executionMode: ExecutionMode
    public let preferredLatency: PreferredLatency
    public let qualityTier: QualityTier
    public let privacyMode: PrivacyMode
    public let budget: ExecutionBudget?
    
    public var preferredModel: ModelID? {
        switch selectionPolicy {
        case .automatic:
            return nil
        case .prefer(let modelID), .require(let modelID):
            return modelID
        }
    }
    
    public var allowsFallback: Bool {
        switch selectionPolicy {
        case .automatic, .prefer:
            return true
        case .require:
            return false
        }
    }

    public init(
        requiredCapabilities: Set<ModelCapability> = [],
        selectionPolicy: ModelSelectionPolicy? = nil,
        executionMode: ExecutionMode = .hybrid,
        preferredLatency: PreferredLatency = .interactive,
        qualityTier: QualityTier = .balanced,
        preferredModel: ModelID? = nil,
        privacyMode: PrivacyMode = .standard,
        budget: ExecutionBudget? = nil,
        allowsFallback: Bool = true
    ) {
        self.requiredCapabilities = requiredCapabilities
        if let selectionPolicy {
            self.selectionPolicy = selectionPolicy
        } else if let preferredModel {
            self.selectionPolicy = allowsFallback ? .prefer(preferredModel) : .require(preferredModel)
        } else {
            self.selectionPolicy = .automatic
        }
        self.executionMode = executionMode
        self.preferredLatency = preferredLatency
        self.qualityTier = qualityTier
        self.privacyMode = privacyMode
        self.budget = budget
    }

    public init(
        requiredCapabilities: Set<ModelCapability> = [],
        executionMode: ExecutionMode = .hybrid,
        preferredLatency: PreferredLatency = .interactive,
        qualityTier: QualityTier = .balanced,
        preferredModel: ModelID? = nil,
        privacyMode: PrivacyMode = .standard,
        budget: ExecutionBudget? = nil,
        allowsFallback: Bool = true
    ) {
        self.init(
            requiredCapabilities: requiredCapabilities,
            selectionPolicy: nil,
            executionMode: executionMode,
            preferredLatency: preferredLatency,
            qualityTier: qualityTier,
            preferredModel: preferredModel,
            privacyMode: privacyMode,
            budget: budget,
            allowsFallback: allowsFallback
        )
    }

    private enum CodingKeys: String, CodingKey {
        case requiredCapabilities
        case selectionPolicy
        case executionMode
        case preferredLatency
        case qualityTier
        case preferredModel
        case privacyMode
        case budget
        case allowsFallback
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let requiredCapabilities = try container.decodeIfPresent(Set<ModelCapability>.self, forKey: .requiredCapabilities) ?? []
        let selectionPolicy = try container.decodeIfPresent(ModelSelectionPolicy.self, forKey: .selectionPolicy)
        let executionMode = try container.decodeIfPresent(ExecutionMode.self, forKey: .executionMode) ?? .hybrid
        let preferredLatency = try container.decodeIfPresent(PreferredLatency.self, forKey: .preferredLatency) ?? .interactive
        let qualityTier = try container.decodeIfPresent(QualityTier.self, forKey: .qualityTier) ?? .balanced
        let preferredModel = try container.decodeIfPresent(ModelID.self, forKey: .preferredModel)
        let privacyMode = try container.decodeIfPresent(PrivacyMode.self, forKey: .privacyMode) ?? .standard
        let budget = try container.decodeIfPresent(ExecutionBudget.self, forKey: .budget)
        let allowsFallback = try container.decodeIfPresent(Bool.self, forKey: .allowsFallback) ?? true
        self.init(
            requiredCapabilities: requiredCapabilities,
            selectionPolicy: selectionPolicy,
            executionMode: executionMode,
            preferredLatency: preferredLatency,
            qualityTier: qualityTier,
            preferredModel: preferredModel,
            privacyMode: privacyMode,
            budget: budget,
            allowsFallback: allowsFallback
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requiredCapabilities, forKey: .requiredCapabilities)
        try container.encode(selectionPolicy, forKey: .selectionPolicy)
        try container.encode(executionMode, forKey: .executionMode)
        try container.encode(preferredLatency, forKey: .preferredLatency)
        try container.encode(qualityTier, forKey: .qualityTier)
        try container.encodeIfPresent(preferredModel, forKey: .preferredModel)
        try container.encode(privacyMode, forKey: .privacyMode)
        try container.encodeIfPresent(budget, forKey: .budget)
        try container.encode(allowsFallback, forKey: .allowsFallback)
    }

    public func updating(
        requiredCapabilities: Set<ModelCapability>? = nil,
        selectionPolicy: ModelSelectionPolicy? = nil,
        preferredLatency: PreferredLatency? = nil,
        qualityTier: QualityTier? = nil,
        privacyMode: PrivacyMode? = nil,
        budget: ExecutionBudget? = nil
    ) -> ExecutionRequirements {
        ExecutionRequirements(
            requiredCapabilities: requiredCapabilities ?? self.requiredCapabilities,
            selectionPolicy: selectionPolicy ?? self.selectionPolicy,
            executionMode: executionMode,
            preferredLatency: preferredLatency ?? self.preferredLatency,
            qualityTier: qualityTier ?? self.qualityTier,
            privacyMode: privacyMode ?? self.privacyMode,
            budget: budget ?? self.budget
        )
    }
}

public enum ModelSelectionPolicy: Hashable, Codable, Sendable {
    case automatic
    case prefer(ModelID)
    case require(ModelID)

    public var preferredModel: ModelID? {
        switch self {
        case .automatic:
            return nil
        case .prefer(let modelID), .require(let modelID):
            return modelID
        }
    }

    public var allowsFallback: Bool {
        switch self {
        case .automatic, .prefer:
            return true
        case .require:
            return false
        }
    }

    public var requiresExactModel: Bool {
        if case .require = self {
            return true
        }
        return false
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
