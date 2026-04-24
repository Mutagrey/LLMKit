public enum ModelCatalogSourceKind: String, Hashable, Codable, Sendable {
    case local
    case remoteVerified
    case fallback
}

public struct ModelCatalogStatus: Hashable, Codable, Sendable {
    public let source: ModelCatalogSourceKind
    public let message: String?

    public init(source: ModelCatalogSourceKind, message: String? = nil) {
        self.source = source
        self.message = message
    }

    public static let local = ModelCatalogStatus(source: .local)
}
