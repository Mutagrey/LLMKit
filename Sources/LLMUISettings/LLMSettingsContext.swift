import Foundation

public struct LLMSettingsContext: Hashable, Sendable {
    public var selectedModelName: String?
    public var selectedModelBackendTitle: String?
    public var selectedModelStatus: String?
    public var selectedModelContextWindowTokens: Int?
    public var catalogSourceTitle: String?
    public var catalogMessage: String?
    public var promptSummary: String?
    public var safetySummary: String?
    public var storageRows: [LLMSettingsInfoRow]
    public var isLowMemoryConstrained: Bool
    public var recommendation: String?

    public init(
        selectedModelName: String? = nil,
        selectedModelBackendTitle: String? = nil,
        selectedModelStatus: String? = nil,
        selectedModelContextWindowTokens: Int? = nil,
        catalogSourceTitle: String? = nil,
        catalogMessage: String? = nil,
        promptSummary: String? = nil,
        safetySummary: String? = nil,
        storageRows: [LLMSettingsInfoRow] = [],
        isLowMemoryConstrained: Bool = false,
        recommendation: String? = nil
    ) {
        self.selectedModelName = selectedModelName
        self.selectedModelBackendTitle = selectedModelBackendTitle
        self.selectedModelStatus = selectedModelStatus
        self.selectedModelContextWindowTokens = selectedModelContextWindowTokens
        self.catalogSourceTitle = catalogSourceTitle
        self.catalogMessage = catalogMessage
        self.promptSummary = promptSummary
        self.safetySummary = safetySummary
        self.storageRows = storageRows
        self.isLowMemoryConstrained = isLowMemoryConstrained
        self.recommendation = recommendation
    }
}
