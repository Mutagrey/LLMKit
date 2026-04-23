import Foundation

public struct ModelSource: Hashable, Codable, Sendable {
    public let provider: ModelSourceProvider
    public let repository: String?
    public let revision: String?
    public let homepageURL: URL?
    public let artifacts: [ModelArtifact]

    public init(
        provider: ModelSourceProvider,
        repository: String? = nil,
        revision: String? = nil,
        homepageURL: URL? = nil,
        artifacts: [ModelArtifact] = []
    ) {
        self.provider = provider
        self.repository = repository
        self.revision = revision
        self.homepageURL = homepageURL
        self.artifacts = artifacts
    }
}

public enum ModelSourceProvider: Hashable, Codable, Sendable {
    case huggingFace
    case remoteURL
    case bundled
    case custom(String)
}
