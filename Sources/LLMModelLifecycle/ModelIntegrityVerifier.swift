import CryptoKit
import Foundation
import LLMCore

public struct ModelIntegrityVerifier: Sendable {
    public init() {}

    public func verifyManifestData(_ data: Data, signature: ModelManifestSignature) throws -> Bool {
        let actual = try Self.digestHex(of: data, algorithm: signature.algorithm)
        guard actual.caseInsensitiveCompare(signature.value) == .orderedSame else {
            throw LLMError.verificationFailed("Manifest signature mismatch.")
        }
        return true
    }

    public func verify(_ descriptor: ModelDescriptor, at artifactRootDirectory: URL) async throws -> Bool {
        guard let source = descriptor.source, !source.artifacts.isEmpty else {
            return true
        }

        let resolver = ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
        for artifact in source.artifacts {
            let fileURL = try resolver.artifactURL(modelID: descriptor.id, artifact: artifact)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw LLMError.verificationFailed("Missing artifact \(artifact.relativePath).")
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let expectedBytes = artifact.byteCount,
               let actualBytes = (attributes[.size] as? NSNumber)?.int64Value,
               actualBytes != expectedBytes {
                throw LLMError.verificationFailed("Artifact size mismatch for \(artifact.relativePath).")
            }

            if let checksum = artifact.checksum {
                let data = try Data(contentsOf: fileURL)
                let actual = try Self.digestHex(of: data, algorithm: checksum.algorithm)
                guard actual.caseInsensitiveCompare(checksum.value) == .orderedSame else {
                    throw LLMError.verificationFailed("Artifact checksum mismatch for \(artifact.relativePath).")
                }
            }
        }

        return true
    }

    static func digestHex(of data: Data, algorithm: String) throws -> String {
        switch algorithm.lowercased() {
        case "sha256":
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        default:
            throw LLMError.verificationFailed("Unsupported verification algorithm: \(algorithm).")
        }
    }
}
