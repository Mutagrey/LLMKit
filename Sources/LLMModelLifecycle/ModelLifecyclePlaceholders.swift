import LLMCore

public struct ManifestLoader: Sendable {
    public init() {}
}

public struct ModelDownloader: Sendable {
    public init() {}
}

public struct ModelIntegrityVerifier: Sendable {
    public init() {}

    public func verify(_ descriptor: ModelDescriptor) async throws -> Bool {
        !descriptor.displayName.isEmpty
    }
}

public struct ModelCompiler: Sendable {
    public init() {}
}

public struct ModelWarmupManager: Sendable {
    public init() {}
}

public struct ModelEvictionManager: Sendable {
    public init() {}
}

public struct StorageQuotaPolicy: Hashable, Sendable {
    public let maximumBytes: UInt64?

    public init(maximumBytes: UInt64? = nil) {
        self.maximumBytes = maximumBytes
    }
}
