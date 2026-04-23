import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LLMCore

public struct ModelArtifactDownloadResult: Hashable, Sendable {
    public let artifactID: String
    public let bytesWritten: Int64

    public init(artifactID: String, bytesWritten: Int64) {
        self.artifactID = artifactID
        self.bytesWritten = bytesWritten
    }
}

public protocol ModelArtifactDownloading: Sendable {
    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult
}

public struct URLSessionModelArtifactDownloader: ModelArtifactDownloading {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        let (temporaryURL, response) = try await session.download(from: artifact.url)
        if let httpResponse = response as? HTTPURLResponse {
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw LLMError.downloadFailed("HTTP \(httpResponse.statusCode) for \(artifact.id)")
            }
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let byteCount = attributes[.size] as? NSNumber

        return ModelArtifactDownloadResult(
            artifactID: artifact.id,
            bytesWritten: byteCount?.int64Value ?? 0
        )
    }
}
