import Foundation

public struct ModelArtifact: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let url: URL
    public let relativePath: String
    public let byteCount: Int64?
    public let checksum: ModelArtifactChecksum?

    public init(
        id: String,
        url: URL,
        relativePath: String,
        byteCount: Int64? = nil,
        checksum: ModelArtifactChecksum? = nil
    ) {
        self.id = id
        self.url = url
        self.relativePath = relativePath
        self.byteCount = byteCount
        self.checksum = checksum
    }
}

public struct ModelArtifactChecksum: Hashable, Codable, Sendable {
    public let algorithm: String
    public let value: String

    public init(algorithm: String, value: String) {
        self.algorithm = algorithm
        self.value = value
    }
}
