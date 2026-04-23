import Foundation

public struct ModelDescriptor: Hashable, Codable, Sendable {
    public let id: ModelID
    public let displayName: String
    public let family: ModelFamily
    public let backend: BackendKind
    public let capabilities: Set<ModelCapability>
    public let minimumOS: String?
    public let minimumRAMGB: Int?
    public let minimumFreeDiskGB: Int?
    public let contextWindowTokens: Int?
    public let supportsStreaming: Bool
    public let supportsTools: Bool
    public let supportsStructuredOutput: Bool
    public let isRemote: Bool
    public let source: ModelSource?
    public let license: ModelLicense?
    public let quantization: Quantization?
    public let estimatedDownloadSizeBytes: Int64?
    public let tags: [String]

    public init(
        id: ModelID,
        displayName: String,
        family: ModelFamily,
        backend: BackendKind,
        capabilities: Set<ModelCapability>,
        minimumOS: String? = nil,
        minimumRAMGB: Int? = nil,
        minimumFreeDiskGB: Int? = nil,
        contextWindowTokens: Int? = nil,
        supportsStreaming: Bool = false,
        supportsTools: Bool = false,
        supportsStructuredOutput: Bool = false,
        isRemote: Bool = false,
        source: ModelSource? = nil,
        license: ModelLicense? = nil,
        quantization: Quantization? = nil,
        estimatedDownloadSizeBytes: Int64? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.family = family
        self.backend = backend
        self.capabilities = capabilities
        self.minimumOS = minimumOS
        self.minimumRAMGB = minimumRAMGB
        self.minimumFreeDiskGB = minimumFreeDiskGB
        self.contextWindowTokens = contextWindowTokens
        self.supportsStreaming = supportsStreaming
        self.supportsTools = supportsTools
        self.supportsStructuredOutput = supportsStructuredOutput
        self.isRemote = isRemote
        self.source = source
        self.license = license
        self.quantization = quantization
        self.estimatedDownloadSizeBytes = estimatedDownloadSizeBytes
        self.tags = tags
    }
}
