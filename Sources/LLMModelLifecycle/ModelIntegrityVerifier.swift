import CryptoKit
import Foundation
import LLMCore

public struct ModelIntegrityVerifier: Sendable {
    public init() {}

    public func verifyManifestData(_ data: Data, signature: ModelManifestSignature) throws -> Bool {
        switch signature.algorithm.lowercased() {
        case "sha256":
            let actual = try Self.digestHex(of: data, algorithm: signature.algorithm)
            guard actual.caseInsensitiveCompare(signature.value) == .orderedSame else {
                throw LLMError.verificationFailed("Manifest signature mismatch.")
            }
        case "ed25519":
            guard let publicKeyValue = signature.publicKeyValue else {
                throw LLMError.verificationFailed("Manifest signature is missing a public key.")
            }
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: Self.data(fromHex: publicKeyValue))
            let signatureData = try Self.data(fromHex: signature.value)
            guard publicKey.isValidSignature(signatureData, for: data) else {
                throw LLMError.verificationFailed("Manifest signature mismatch.")
            }
        default:
            throw LLMError.verificationFailed("Unsupported verification algorithm: \(signature.algorithm).")
        }
        return true
    }

    public func verify(_ descriptor: ModelDescriptor, at artifactRootDirectory: URL) async throws -> Bool {
        guard let source = descriptor.source, !source.artifacts.isEmpty else {
            return true
        }

        for artifact in source.artifacts {
            _ = try verifyArtifact(artifact, modelID: descriptor.id, at: artifactRootDirectory)
        }

        return true
    }

    func verifyArtifact(_ artifact: ModelArtifact, modelID: ModelID, at artifactRootDirectory: URL) throws -> Int64 {
        let resolver = ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
        let fileURL = try resolver.artifactURL(modelID: modelID, artifact: artifact)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw LLMError.verificationFailed("Missing artifact \(artifact.relativePath).")
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let actualBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        if let expectedBytes = artifact.byteCount,
           actualBytes != expectedBytes {
            throw LLMError.verificationFailed("Artifact size mismatch for \(artifact.relativePath).")
        }

        if let checksum = artifact.checksum {
            let actual = try Self.digestHex(ofFileAt: fileURL, algorithm: checksum.algorithm)
            guard actual.caseInsensitiveCompare(checksum.value) == .orderedSame else {
                throw LLMError.verificationFailed("Artifact checksum mismatch for \(artifact.relativePath).")
            }
        }

        return actualBytes
    }

    static func digestHex(of data: Data, algorithm: String) throws -> String {
        switch algorithm.lowercased() {
        case "sha256":
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        default:
            throw LLMError.verificationFailed("Unsupported verification algorithm: \(algorithm).")
        }
    }

    static func digestHex(ofFileAt fileURL: URL, algorithm: String, chunkSize: Int = 8 * 1_024 * 1_024) throws -> String {
        guard chunkSize > 0 else {
            throw LLMError.verificationFailed("Invalid checksum chunk size.")
        }

        switch algorithm.lowercased() {
        case "sha256":
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer {
                try? fileHandle.close()
            }

            var hasher = SHA256()
            while true {
                if Task.isCancelled {
                    throw CancellationError()
                }
                let chunk = try fileHandle.read(upToCount: chunkSize) ?? Data()
                if chunk.isEmpty {
                    break
                }
                hasher.update(data: chunk)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        default:
            throw LLMError.verificationFailed("Unsupported verification algorithm: \(algorithm).")
        }
    }

    static func hexString(for data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func data(fromHex value: String) throws -> Data {
        guard value.count.isMultiple(of: 2) else {
            throw LLMError.verificationFailed("Invalid hex-encoded verification value.")
        }

        var data = Data()
        var index = value.startIndex
        while index < value.endIndex {
            let nextIndex = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<nextIndex], radix: 16) else {
                throw LLMError.verificationFailed("Invalid hex-encoded verification value.")
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}
