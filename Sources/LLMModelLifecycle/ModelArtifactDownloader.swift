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

public protocol ModelArtifactDownloadCacheCleaning: Sendable {
    func removeCachedDownload(for artifact: ModelArtifact, at destination: URL) throws
}

public struct URLSessionModelArtifactDownloader: ProgressReportingModelArtifactDownloading {
    typealias DownloadAttempt = @Sendable (
        _ artifact: ModelArtifact,
        _ destination: URL,
        _ resumeData: Data?,
        _ onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) async throws -> ModelArtifactDownloadResult

    private let maximumResumeAttempts: Int
    private let attemptDownload: DownloadAttempt

    public init(session: URLSession = .shared, maximumResumeAttempts: Int = 3) {
        self.maximumResumeAttempts = max(0, maximumResumeAttempts)
        self.attemptDownload = { artifact, destination, resumeData, onProgress in
            try await Self.runURLSessionDownload(
                artifact: artifact,
                destination: destination,
                resumeData: resumeData,
                configuration: session.configuration,
                onProgress: onProgress
            )
        }
    }

    init(maximumResumeAttempts: Int = 3, attemptDownload: @escaping DownloadAttempt) {
        self.maximumResumeAttempts = max(0, maximumResumeAttempts)
        self.attemptDownload = attemptDownload
    }

    public func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        try await download(artifact, to: destination) { _ in }
    }

    public func download(
        _ artifact: ModelArtifact,
        to destination: URL,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) async throws -> ModelArtifactDownloadResult {
        var resumeData = try cachedResumeData(for: destination)
        var resumeAttempts = 0

        while true {
            try Task.checkCancellation()

            do {
                let result = try await attemptDownload(artifact, destination, resumeData, onProgress)
                try removeCachedDownload(for: artifact, at: destination)
                return result
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as ResumableDownloadAttemptError {
                if let nextResumeData = error.resumeData, !nextResumeData.isEmpty {
                    resumeData = nextResumeData
                    try? Self.cacheResumeData(nextResumeData, for: destination)
                }

                if Self.isTransient(error.underlyingError), resumeAttempts < maximumResumeAttempts {
                    resumeAttempts += 1
                    continue
                }

                throw Self.normalizedDownloadError(error.underlyingError, artifactID: artifact.id)
            } catch {
                if Self.isTransient(error), resumeAttempts < maximumResumeAttempts {
                    resumeAttempts += 1
                    resumeData = nil
                    continue
                }

                throw Self.normalizedDownloadError(error, artifactID: artifact.id)
            }
        }
    }

    private static func runURLSessionDownload(
        artifact: ModelArtifact,
        destination: URL,
        resumeData: Data?,
        configuration: URLSessionConfiguration,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) async throws -> ModelArtifactDownloadResult {
        let delegate = URLSessionArtifactDownloadDelegate(
            artifact: artifact,
            destination: destination,
            onProgress: onProgress
        )
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        let taskBox = URLSessionDownloadTaskBox()
        let continuationBox = URLSessionDownloadContinuationBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuationBox.set(continuation)
                delegate.onComplete = { result in
                    session.finishTasksAndInvalidate()
                    continuationBox.resume(with: result)
                }
                let downloadTask: URLSessionDownloadTask
                if let resumeData, !resumeData.isEmpty {
                    downloadTask = session.downloadTask(withResumeData: resumeData)
                } else {
                    downloadTask = session.downloadTask(with: artifact.url)
                }
                taskBox.set(downloadTask)
                if Task.isCancelled {
                    delegate.cancel()
                    cancelDownload(
                        taskBox: taskBox,
                        destination: destination,
                        session: session,
                        continuationBox: continuationBox
                    )
                    return
                }
                downloadTask.resume()
            }
        } onCancel: {
            delegate.cancel()
            cancelDownload(
                taskBox: taskBox,
                destination: destination,
                session: session,
                continuationBox: continuationBox
            )
        }
    }

    private static func cancelDownload(
        taskBox: URLSessionDownloadTaskBox,
        destination: URL,
        session: URLSession,
        continuationBox: URLSessionDownloadContinuationBox
    ) {
        let didCancelTask = taskBox.cancelByProducingResumeData { resumeData in
            if let resumeData, !resumeData.isEmpty {
                try? cacheResumeData(resumeData, for: destination)
            }
            session.invalidateAndCancel()
            continuationBox.resume(with: .failure(CancellationError()))
        }
        if !didCancelTask {
            session.invalidateAndCancel()
            continuationBox.resume(with: .failure(CancellationError()))
            return
        }
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            session.invalidateAndCancel()
            continuationBox.resume(with: .failure(CancellationError()))
        }
    }

    private func cachedResumeData(for destination: URL) throws -> Data? {
        let url = Self.resumeDataURL(for: destination)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    private static func cacheResumeData(_ data: Data, for destination: URL) throws {
        let url = resumeDataURL(for: destination)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
    }

    private static func resumeDataURL(for destination: URL) -> URL {
        destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).resumeData")
    }

    private static func isTransient(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }

        switch urlError.code {
        case .networkConnectionLost,
             .timedOut,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    private static func normalizedDownloadError(_ error: Error, artifactID: String) -> LLMError {
        if let llmError = error as? LLMError {
            return llmError
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost:
                return .downloadFailed("Network connection was lost while downloading \(artifactID). Retry the installation.")
            case .timedOut:
                return .downloadFailed("Download timed out for \(artifactID). Retry the installation.")
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return .downloadFailed("Could not connect while downloading \(artifactID). Retry the installation.")
            case .notConnectedToInternet:
                return .downloadFailed("No internet connection while downloading \(artifactID).")
            case .cancelled:
                return .cancelled
            default:
                return .downloadFailed("Download failed for \(artifactID). Retry the installation.")
            }
        }

        return .downloadFailed("Download failed for \(artifactID). Retry the installation.")
    }
}

extension URLSessionModelArtifactDownloader: ModelArtifactDownloadCacheCleaning {
    public func removeCachedDownload(for artifact: ModelArtifact, at destination: URL) throws {
        let url = Self.resumeDataURL(for: destination)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

struct ResumableDownloadAttemptError: Error, Sendable {
    let underlyingError: Error
    let resumeData: Data?
}

private final class URLSessionArtifactDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let artifact: ModelArtifact
    let destination: URL

    var onComplete: ((Result<ModelArtifactDownloadResult, Error>) -> Void)?

    private let progressReporter: URLSessionDownloadProgressReporter
    private let lock = NSLock()
    private var completionResult: Result<ModelArtifactDownloadResult, Error>?
    private var completed = false
    private var cancelled = false

    init(
        artifact: ModelArtifact,
        destination: URL,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) {
        self.artifact = artifact
        self.destination = destination
        self.progressReporter = URLSessionDownloadProgressReporter(onProgress: onProgress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : artifact.byteCount
        progressReporter.report(
            ModelArtifactDownloadProgress(
                artifactID: artifact.id,
                bytesWritten: totalBytesWritten,
                expectedTotalBytes: expected
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            lock.lock()
            let isCancelled = cancelled
            lock.unlock()
            if isCancelled {
                throw CancellationError()
            }

            if let httpResponse = downloadTask.response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw LLMError.downloadFailed("HTTP \(httpResponse.statusCode) for \(artifact.id)")
            }

            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0

            lock.lock()
            completionResult = .success(ModelArtifactDownloadResult(
                artifactID: artifact.id,
                bytesWritten: byteCount
            ))
            lock.unlock()
        } catch {
            lock.lock()
            completionResult = .failure(error)
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
        progressReporter.cancel()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                finish(with: .failure(CancellationError()))
                return
            }
            finish(with: .failure(ResumableDownloadAttemptError(
                underlyingError: error,
                resumeData: Self.resumeData(from: error)
            )))
            return
        }

        lock.lock()
        let completionResult = self.completionResult
        lock.unlock()

        guard let completionResult else {
            finish(with: .failure(LLMError.downloadFailed("Missing downloaded file for \(artifact.id)")))
            return
        }

        finish(with: completionResult)
    }

    private func finish(with result: Result<ModelArtifactDownloadResult, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else {
            return
        }
        completed = true
        progressReporter.cancel()
        onComplete?(result)
        onComplete = nil
    }

    private static func resumeData(from error: Error) -> Data? {
        let userInfo = (error as NSError).userInfo
        return userInfo[NSURLSessionDownloadTaskResumeData] as? Data
    }
}

private final class URLSessionDownloadProgressReporter: @unchecked Sendable {
    private let onProgress: @Sendable (ModelArtifactDownloadProgress) async -> Void
    private let lock = NSLock()
    private var latestProgress: ModelArtifactDownloadProgress?
    private var isPublishing = false
    private var isCancelled = false

    init(onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void) {
        self.onProgress = onProgress
    }

    func report(_ progress: ModelArtifactDownloadProgress) {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            return
        }
        latestProgress = progress
        guard !isPublishing else {
            lock.unlock()
            return
        }
        isPublishing = true
        lock.unlock()

        Task { [weak self] in
            await self?.publishLoop()
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        latestProgress = nil
        lock.unlock()
    }

    private func publishLoop() async {
        while true {
            guard let progress = nextProgress() else {
                return
            }
            await onProgress(progress)
        }
    }

    private func nextProgress() -> ModelArtifactDownloadProgress? {
        lock.lock()
        defer { lock.unlock() }

        if isCancelled {
            isPublishing = false
            return nil
        }

        guard let progress = latestProgress else {
            isPublishing = false
            return nil
        }

        latestProgress = nil
        return progress
    }
}

private final class URLSessionDownloadContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ModelArtifactDownloadResult, Error>?
    private var pendingResult: Result<ModelArtifactDownloadResult, Error>?
    private var completed = false

    func set(_ continuation: CheckedContinuation<ModelArtifactDownloadResult, Error>) {
        let resultToResume: Result<ModelArtifactDownloadResult, Error>?
        lock.lock()
        if let pendingResult {
            resultToResume = pendingResult
            self.pendingResult = nil
        } else if completed {
            resultToResume = .failure(CancellationError())
        } else {
            self.continuation = continuation
            resultToResume = nil
        }
        lock.unlock()

        if let resultToResume {
            continuation.resume(with: resultToResume)
        }
    }

    func resume(with result: Result<ModelArtifactDownloadResult, Error>) {
        let continuationToResume: CheckedContinuation<ModelArtifactDownloadResult, Error>?
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        continuationToResume = continuation
        continuation = nil
        if continuationToResume == nil {
            pendingResult = result
        }
        lock.unlock()

        continuationToResume?.resume(with: result)
    }
}

private final class URLSessionDownloadTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDownloadTask?

    func set(_ task: URLSessionDownloadTask) {
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func cancelByProducingResumeData(_ completionHandler: @escaping @Sendable (Data?) -> Void) -> Bool {
        lock.lock()
        let task = self.task
        lock.unlock()

        guard let task else {
            return false
        }

        task.cancel(byProducingResumeData: completionHandler)
        return true
    }
}
