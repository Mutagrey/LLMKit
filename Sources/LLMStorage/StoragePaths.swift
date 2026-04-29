import Foundation
import LLMCore

public struct StoragePaths: Hashable, Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    public static func defaultRootDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("LLMKit", isDirectory: true)
    }

    public var manifestsDirectory: URL {
        rootDirectory.appendingPathComponent("manifests", isDirectory: true)
    }

    public var modelsDirectory: URL {
        rootDirectory.appendingPathComponent("models", isDirectory: true)
    }

    public var sessionsDirectory: URL {
        rootDirectory.appendingPathComponent("Sessions", isDirectory: true)
    }

    public var sessionIndexURL: URL {
        sessionsDirectory.appendingPathComponent("index.json")
    }

    public func sessionURL(id: SessionID) -> URL {
        sessionsDirectory.appendingPathComponent("\(safeFileName(for: id)).json")
    }

    private func safeFileName(for id: SessionID) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return id.rawValue.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }
}
