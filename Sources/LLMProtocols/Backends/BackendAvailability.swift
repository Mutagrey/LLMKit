import LLMCore

public struct BackendAvailability: Hashable, Sendable {
    public let status: AvailabilityStatus
    public let reason: String?

    public init(status: AvailabilityStatus, reason: String? = nil) {
        self.status = status
        self.reason = reason
    }

    public static let available = BackendAvailability(status: .available)
    public static let unsupported = BackendAvailability(status: .unsupported)
}

public struct BackendCapabilities: Hashable, Sendable {
    public let backend: BackendKind
    public let capabilities: Set<ModelCapability>

    public init(backend: BackendKind, capabilities: Set<ModelCapability>) {
        self.backend = backend
        self.capabilities = capabilities
    }
}
