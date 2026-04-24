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

public struct ModelArtifactDownloadProgress: Hashable, Sendable {
    public let artifactID: String
    public let bytesWritten: Int64
    public let expectedTotalBytes: Int64?

    public init(artifactID: String, bytesWritten: Int64, expectedTotalBytes: Int64? = nil) {
        self.artifactID = artifactID
        self.bytesWritten = bytesWritten
        self.expectedTotalBytes = expectedTotalBytes
    }
}

public protocol ModelArtifactDownloading: Sendable {
    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult
}

public protocol ProgressReportingModelArtifactDownloading: ModelArtifactDownloading {
    func download(
        _ artifact: ModelArtifact,
        to destination: URL,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) async throws -> ModelArtifactDownloadResult
}

public struct URLSessionModelArtifactDownloader: ProgressReportingModelArtifactDownloading {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        try await download(artifact, to: destination) { _ in }
    }

    public func download(
        _ artifact: ModelArtifact,
        to destination: URL,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) async throws -> ModelArtifactDownloadResult {
        let delegate = URLSessionArtifactDownloadDelegate(
            artifact: artifact,
            destination: destination,
            onProgress: onProgress
        )
        let session = URLSession(
            configuration: session.configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            delegate.onComplete = { result in
                session.invalidateAndCancel()
                continuation.resume(with: result)
            }
            session.downloadTask(with: artifact.url).resume()
        }
    }
}

private final class URLSessionArtifactDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let artifact: ModelArtifact
    let destination: URL
    let onProgress: @Sendable (ModelArtifactDownloadProgress) async -> Void

    var onComplete: ((Result<ModelArtifactDownloadResult, Error>) -> Void)?

    private let lock = NSLock()
    private var temporaryURL: URL?
    private var completed = false

    init(
        artifact: ModelArtifact,
        destination: URL,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) {
        self.artifact = artifact
        self.destination = destination
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : artifact.byteCount
        Task {
            await onProgress(
                ModelArtifactDownloadProgress(
                    artifactID: artifact.id,
                    bytesWritten: totalBytesWritten,
                    expectedTotalBytes: expected
                )
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        lock.lock()
        temporaryURL = location
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            finish(with: .failure(error))
            return
        }

        do {
            guard let response = task.response else {
                throw LLMError.downloadFailed("Missing response for \(artifact.id)")
            }
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw LLMError.downloadFailed("HTTP \(httpResponse.statusCode) for \(artifact.id)")
            }

            guard let temporaryURL else {
                throw LLMError.downloadFailed("Missing downloaded file for \(artifact.id)")
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
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0

            finish(with: .success(ModelArtifactDownloadResult(
                artifactID: artifact.id,
                bytesWritten: byteCount
            )))
        } catch {
            finish(with: .failure(error))
        }
    }

    private func finish(with result: Result<ModelArtifactDownloadResult, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else {
            return
        }
        completed = true
        onComplete?(result)
        onComplete = nil
    }
}
