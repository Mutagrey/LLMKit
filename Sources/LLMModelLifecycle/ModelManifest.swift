import Foundation
import LLMCore

public struct ModelManifest: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let models: [ModelDescriptor]
    public let createdAt: Date

    public init(id: String, models: [ModelDescriptor], createdAt: Date = Date()) {
        self.id = id
        self.models = models
        self.createdAt = createdAt
    }
}

public struct ModelManifestSignature: Hashable, Codable, Sendable {
    public let algorithm: String
    public let value: String

    public init(algorithm: String, value: String) {
        self.algorithm = algorithm
        self.value = value
    }
}
