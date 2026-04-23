import Foundation
import LLMCore

public struct ModelArtifactLocationResolver: Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    public static func defaultRootDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("LLMKit", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    public func modelDirectory(for modelID: ModelID) -> URL {
        rootDirectory.appendingPathComponent(safeDirectoryName(for: modelID), isDirectory: true)
    }

    public func artifactURL(modelID: ModelID, artifact: ModelArtifact) throws -> URL {
        guard !artifact.relativePath.hasPrefix("/") else {
            throw LLMError.downloadFailed("Artifact path must be relative: \(artifact.relativePath).")
        }

        let pathComponents = artifact.relativePath.split(separator: "/").map(String.init)
        guard !pathComponents.isEmpty, !pathComponents.contains("..") else {
            throw LLMError.downloadFailed("Invalid artifact path: \(artifact.relativePath).")
        }

        return pathComponents.reduce(modelDirectory(for: modelID)) { url, component in
            url.appendingPathComponent(component)
        }
    }

    private func safeDirectoryName(for modelID: ModelID) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return modelID.rawValue.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }
}
