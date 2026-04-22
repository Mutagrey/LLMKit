import Foundation

public struct EmbeddingRequest: Hashable, Codable, Sendable {
    public let input: String
    public let preferredModel: ModelID?

    public init(input: String, preferredModel: ModelID? = nil) {
        self.input = input
        self.preferredModel = preferredModel
    }
}
