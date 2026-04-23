import Foundation

public struct ModelLicense: Hashable, Codable, Sendable {
    public let name: String
    public let spdxIdentifier: String?
    public let url: URL?

    public init(name: String, spdxIdentifier: String? = nil, url: URL? = nil) {
        self.name = name
        self.spdxIdentifier = spdxIdentifier
        self.url = url
    }
}
