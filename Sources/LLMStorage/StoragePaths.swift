import Foundation
import LLMCore

public struct StoragePaths: Hashable, Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    public var manifestsDirectory: URL {
        rootDirectory.appendingPathComponent("manifests", isDirectory: true)
    }

    public var modelsDirectory: URL {
        rootDirectory.appendingPathComponent("models", isDirectory: true)
    }

    public func sessionURL(id: SessionID) -> URL {
        rootDirectory.appendingPathComponent("sessions", isDirectory: true).appendingPathComponent("\(id.rawValue).json")
    }
}
