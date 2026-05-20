import Foundation
import LLMCore
import LLMProtocols

public actor ModelInstallCoordinator: ModelLifecycleService, ModelLifecycleMaintenanceService, InstalledModelProviding {
    private var records: [ModelID: InstalledModelRecord]
    private let stateMachine: InstallStateMachine
    private let recordStore: InstalledModelRecordStore?
    private let artifactRootDirectory: URL?
    private let artifactDownloader: any ModelArtifactDownloading
    private let integrityVerifier: ModelIntegrityVerifier
    private let interruptionPolicy: ModelInstallInterruptionPolicy
    private let diskSpaceProvider: any ModelInstallDiskSpaceProviding
    private var hasLoadedPersistedRecords: Bool
    private var progressStore: InstallProgressStore? {
        artifactRootDirectory.map(InstallProgressStore.init(rootDirectory:))
    }

    public init(
        records: [InstalledModelRecord] = [],
        stateMachine: InstallStateMachine? = nil,
        recordStore: InstalledModelRecordStore? = nil,
        artifactRootDirectory: URL? = nil,
        artifactDownloader: any ModelArtifactDownloading = URLSessionModelArtifactDownloader(),
        integrityVerifier: ModelIntegrityVerifier = ModelIntegrityVerifier(),
        interruptionPolicy: ModelInstallInterruptionPolicy = .default,
        diskSpaceProvider: any ModelInstallDiskSpaceProviding = FileSystemModelInstallDiskSpaceProvider(),
        loadedPersistedRecords: Bool? = nil
    ) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.descriptor.id, $0) })
        self.stateMachine = stateMachine ?? InstallStateMachine(
            states: Dictionary(uniqueKeysWithValues: records.map { ($0.descriptor.id, $0.installState) })
        )
        self.recordStore = recordStore
        self.artifactRootDirectory = artifactRootDirectory
        self.artifactDownloader = artifactDownloader
        self.integrityVerifier = integrityVerifier
        self.interruptionPolicy = interruptionPolicy
        self.diskSpaceProvider = diskSpaceProvider
        self.hasLoadedPersistedRecords = loadedPersistedRecords ?? (recordStore == nil || !records.isEmpty)
    }

    public static func persisted(recordStore: InstalledModelRecordStore) async throws -> ModelInstallCoordinator {
        let records = try await recordStore.load()
        return ModelInstallCoordinator(records: records, recordStore: recordStore, loadedPersistedRecords: true)
    }

    public func installedModels() async throws -> [InstalledModelRecord] {
        try await ensureLoadedPersistedRecords()
        return Array(records.values).sorted { $0.descriptor.displayName < $1.descriptor.displayName }
    }

    public func installedRecord(for id: ModelID) async throws -> InstalledModelRecord? {
        try await ensureLoadedPersistedRecords()
        return records[id]
    }

    public func state(for modelID: ModelID) async throws -> InstallState {
        try await ensureLoadedPersistedRecords()
        let state = await stateMachine.state(for: modelID)
        guard state == .notInstalled, records[modelID] == nil, let progressStore else {
            return state
        }
        if let restoredState = try progressStore.restoredState(for: modelID) {
            await stateMachine.transition(modelID: modelID, to: restoredState)
            return restoredState
        }
        return state
    }

    public func deleteInstalledModel(_ modelID: ModelID) async throws {
        try await ensureLoadedPersistedRecords()

        if let artifactRootDirectory {
            let directory = ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
                .modelDirectory(for: modelID)
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        }

        records[modelID] = nil
        await stateMachine.transition(modelID: modelID, to: .notInstalled)
        try await recordStore?.save(Array(records.values))
    }

    public func storageUsage() async throws -> ModelStorageUsage {
        try await ensureLoadedPersistedRecords()
        var modelBytes: [ModelID: Int64] = [:]
        for modelID in records.keys {
            modelBytes[modelID] = try storageUsageWithoutLoading(for: modelID)
        }

        let diskUsage = try diskUsageSnapshot()
        return ModelStorageUsage(
            totalBytes: modelBytes.values.reduce(0, +),
            modelBytes: modelBytes,
            availableBytes: diskUsage.availableBytes,
            capacityBytes: diskUsage.capacityBytes
        )
    }

    public func storageUsage(for modelID: ModelID) async throws -> Int64 {
        try await ensureLoadedPersistedRecords()
        return try storageUsageWithoutLoading(for: modelID)
    }

    public nonisolated func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let record = try await completeInstall(descriptor, continuation: continuation)
                    continuation.yield(.stateChanged(descriptor.id, .ready))
                    continuation.yield(.completed(record))
                    continuation.finish()
                } catch {
                    let llmError = Self.mapInstallError(error)
                    if llmError == .cancelled {
                        try? await handleCancellation(for: descriptor)
                        let cancellationState = await installStateAfterCancellation(for: descriptor.id)
                        await stateMachine.transition(modelID: descriptor.id, to: cancellationState)
                        continuation.yield(.stateChanged(descriptor.id, cancellationState))
                    } else {
                        await stateMachine.transition(modelID: descriptor.id, to: .failed(Self.description(for: llmError)))
                        continuation.yield(.failed(descriptor.id, llmError))
                    }
                    continuation.finish(throwing: llmError)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func completeInstall(
        _ descriptor: ModelDescriptor,
        continuation: AsyncThrowingStream<ModelInstallEvent, Error>.Continuation
    ) async throws -> InstalledModelRecord {
        try await ensureLoadedPersistedRecords()
        try await downloadArtifacts(for: descriptor, continuation: continuation)
        try await verifyArtifacts(for: descriptor, continuation: continuation)
        await stateMachine.transition(modelID: descriptor.id, to: .ready)
        let record = InstalledModelRecord(descriptor: descriptor, installState: .ready, installedAt: Date())
        records[descriptor.id] = record
        try await recordStore?.save(Array(records.values))
        try? progressStore?.remove(modelID: descriptor.id)
        return record
    }

    private func downloadArtifacts(
        for descriptor: ModelDescriptor,
        continuation: AsyncThrowingStream<ModelInstallEvent, Error>.Continuation
    ) async throws {
        guard let source = descriptor.source, !source.artifacts.isEmpty else {
            return
        }
        guard let artifactRootDirectory else {
            throw LLMError.downloadFailed("No artifact root directory configured for \(descriptor.id.rawValue).")
        }
        let progressStore = InstallProgressStore(rootDirectory: artifactRootDirectory)

        let preflight = try preflightDownload(
            for: descriptor,
            artifacts: source.artifacts,
            artifactRootDirectory: artifactRootDirectory,
            progressStore: progressStore
        )
        try ensureSufficientDiskSpace(
            for: descriptor,
            artifactRootDirectory: artifactRootDirectory,
            requiredBytes: preflight.requiredDownloadBytes
        )

        let tracker = DownloadProgressTracker(
            totalExpectedBytes: preflight.totalExpectedBytes?.bytes,
            isTotalEstimated: preflight.totalExpectedBytes?.isEstimated ?? true,
            totalArtifacts: source.artifacts.count
        )
        let resolver = ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
        var hasPublishedDownloadState = false

        if preflight.restoredDownloadedBytes == 0, preflight.verifiedExistingBytes.isEmpty {
            await stateMachine.transition(modelID: descriptor.id, to: .downloading(progress: 0))
            continuation.yield(.stateChanged(descriptor.id, .downloading(progress: 0)))
            hasPublishedDownloadState = true
        }

        for artifact in source.artifacts {
            try Task.checkCancellation()
            let destination = try resolver.artifactURL(modelID: descriptor.id, artifact: artifact)

            if let restoredBytes = try preflight.verifiedExistingBytes[artifact.id] ?? resumeExistingArtifactIfPossible(
                artifact,
                modelID: descriptor.id,
                artifactRootDirectory: artifactRootDirectory
            ) {
                let resumedDetail = tracker.restoreCompletedArtifact(artifact, bytes: restoredBytes)
                try await publishDownloadProgressIfNeeded(
                    descriptorID: descriptor.id,
                    continuation: continuation,
                    progress: resumedDetail,
                    tracker: tracker,
                    includeStateChange: !hasPublishedDownloadState
                )
                hasPublishedDownloadState = true
                continue
            }

            if let partialDetail = tracker.restorePartialArtifact(
                artifact,
                bytes: preflight.restoredDownloadedBytes - tracker.completedBytes
            ) {
                try await publishDownloadProgressIfNeeded(
                    descriptorID: descriptor.id,
                    continuation: continuation,
                    progress: partialDetail,
                    tracker: tracker,
                    includeStateChange: !hasPublishedDownloadState
                )
                hasPublishedDownloadState = true
            }

            let result: ModelArtifactDownloadResult
            if let progressDownloader = artifactDownloader as? any ProgressReportingModelArtifactDownloading {
                result = try await progressDownloader.download(artifact, to: destination) { progress in
                    await self.updateDownloadProgress(
                        descriptorID: descriptor.id,
                        continuation: continuation,
                        artifactProgress: progress,
                        tracker: tracker
                    )
                }
            } else {
                result = try await artifactDownloader.download(artifact, to: destination)
            }

            let overallDetail = tracker.completeArtifact(artifact, resultBytes: result.bytesWritten)
            try await publishDownloadProgressIfNeeded(
                descriptorID: descriptor.id,
                continuation: continuation,
                progress: overallDetail,
                tracker: tracker
            )
        }

        await stateMachine.transition(modelID: descriptor.id, to: .verifying)
        continuation.yield(.stateChanged(descriptor.id, .verifying))
    }

    private func preflightDownload(
        for descriptor: ModelDescriptor,
        artifacts: [ModelArtifact],
        artifactRootDirectory: URL,
        progressStore: InstallProgressStore
    ) throws -> DownloadPreflightResult {
        let restoredDownloadedBytes = try progressStore.restoredDownloadedBytes(for: descriptor.id)
        var verifiedExistingBytes: [String: Int64] = [:]
        for artifact in artifacts {
            if let bytes = try resumeExistingArtifactIfPossible(
                artifact,
                modelID: descriptor.id,
                artifactRootDirectory: artifactRootDirectory
            ) {
                verifiedExistingBytes[artifact.id] = bytes
            }
        }

        let totalExpectedBytes = expectedTotalBytes(for: descriptor, artifacts: artifacts)
        let verifiedBytes = verifiedExistingBytes.values.reduce(0, +)
        return DownloadPreflightResult(
            totalExpectedBytes: totalExpectedBytes,
            requiredDownloadBytes: totalExpectedBytes.map { max($0.bytes - verifiedBytes, 0) },
            verifiedExistingBytes: verifiedExistingBytes,
            restoredDownloadedBytes: restoredDownloadedBytes
        )
    }

    private func ensureSufficientDiskSpace(
        for descriptor: ModelDescriptor,
        artifactRootDirectory: URL,
        requiredBytes: Int64?
    ) throws {
        guard let requiredBytes, requiredBytes > 0 else {
            return
        }
        guard let availableBytes = try diskSpaceProvider.availableBytes(at: artifactRootDirectory) else {
            return
        }
        guard availableBytes >= requiredBytes else {
            throw LLMError.downloadFailed(
                "Not enough disk space to download \(descriptor.displayName). Need \(Self.byteCountTitle(requiredBytes)) free, \(Self.byteCountTitle(availableBytes)) available."
            )
        }
    }

    private func resumeExistingArtifactIfPossible(
        _ artifact: ModelArtifact,
        modelID: ModelID,
        artifactRootDirectory: URL
    ) throws -> Int64? {
        do {
            return try integrityVerifier.verifyArtifact(artifact, modelID: modelID, at: artifactRootDirectory)
        } catch let error as LLMError {
            guard case .verificationFailed = error else {
                throw error
            }

            let artifactURL = try ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
                .artifactURL(modelID: modelID, artifact: artifact)
            if FileManager.default.fileExists(atPath: artifactURL.path) {
                try FileManager.default.removeItem(at: artifactURL)
            }
            return nil
        }
    }

    private func verifyArtifacts(
        for descriptor: ModelDescriptor,
        continuation: AsyncThrowingStream<ModelInstallEvent, Error>.Continuation
    ) async throws {
        try Task.checkCancellation()

        guard let artifactRootDirectory else {
            if descriptor.source?.artifacts.isEmpty == false {
                throw LLMError.verificationFailed("No artifact root directory configured for \(descriptor.id.rawValue).")
            }
            return
        }

        if descriptor.source?.artifacts.isEmpty == false {
            await stateMachine.transition(modelID: descriptor.id, to: .verifying)
            continuation.yield(.stateChanged(descriptor.id, .verifying))
        }

        _ = try await integrityVerifier.verify(descriptor, at: artifactRootDirectory)
    }

    private func handleCancellation(for descriptor: ModelDescriptor) async throws {
        switch interruptionPolicy.cancellationBehavior {
        case .preserveVerifiedArtifactsForResume:
            try await cleanupInterruptedArtifactsForResume(descriptor)
        case .removeAllArtifacts:
            try cleanupCachedDownloads(for: descriptor)
            try await cleanupAllArtifacts(for: descriptor.id)
        }
    }

    private func installStateAfterCancellation(for modelID: ModelID) async -> InstallState {
        switch interruptionPolicy.cancellationBehavior {
        case .preserveVerifiedArtifactsForResume:
            let state = await stateMachine.state(for: modelID)
            let progress = progressFraction(for: state)
            return .paused(progress: progress)
        case .removeAllArtifacts:
            return .notInstalled
        }
    }

    private func progressFraction(for state: InstallState) -> Double {
        switch state {
        case .downloading(let progress), .paused(let progress):
            return DownloadProgressTracker.normalizedFraction(progress)
        case .downloaded, .verifying, .compiling:
            return 1
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return 0
        }
    }

    private func cleanupInterruptedArtifactsForResume(_ descriptor: ModelDescriptor) async throws {
        guard
            let artifactRootDirectory,
            let artifacts = descriptor.source?.artifacts,
            !artifacts.isEmpty
        else {
            return
        }

        for artifact in artifacts {
            let artifactURL = try ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
                .artifactURL(modelID: descriptor.id, artifact: artifact)

            guard FileManager.default.fileExists(atPath: artifactURL.path) else {
                continue
            }

            do {
                _ = try integrityVerifier.verifyArtifact(
                    artifact,
                    modelID: descriptor.id,
                    at: artifactRootDirectory
                )
            } catch let error as LLMError {
                guard case .verificationFailed = error else {
                    throw error
                }
                try FileManager.default.removeItem(at: artifactURL)
            }
        }
    }

    private func cleanupCachedDownloads(for descriptor: ModelDescriptor) throws {
        guard
            let artifactRootDirectory,
            let artifacts = descriptor.source?.artifacts,
            !artifacts.isEmpty,
            let cacheCleaner = artifactDownloader as? any ModelArtifactDownloadCacheCleaning
        else {
            return
        }

        for artifact in artifacts {
            let artifactURL = try ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
                .artifactURL(modelID: descriptor.id, artifact: artifact)
            try cacheCleaner.removeCachedDownload(for: artifact, at: artifactURL)
        }
    }

    private func cleanupAllArtifacts(for modelID: ModelID) async throws {
        guard let artifactRootDirectory else {
            return
        }

        let directory = ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
            .modelDirectory(for: modelID)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func expectedTotalBytes(for descriptor: ModelDescriptor, artifacts: [ModelArtifact]) -> DownloadExpectedBytes? {
        let knownBytes = artifacts.compactMap(\.byteCount)
        let total = knownBytes.reduce(Int64(0), +)
        if knownBytes.count == artifacts.count, total > 0 {
            return DownloadExpectedBytes(bytes: total, isEstimated: false)
        }

        if let estimatedDownloadSizeBytes = descriptor.estimatedDownloadSizeBytes, estimatedDownloadSizeBytes > 0 {
            return DownloadExpectedBytes(bytes: estimatedDownloadSizeBytes, isEstimated: true)
        }
        return nil
    }

    private func updateDownloadProgress(
        descriptorID: ModelID,
        continuation: AsyncThrowingStream<ModelInstallEvent, Error>.Continuation,
        artifactProgress: ModelArtifactDownloadProgress,
        tracker: DownloadProgressTracker
    ) async {
        let progressDetail = tracker.updateArtifactProgress(artifactProgress)

        try? await publishDownloadProgressIfNeeded(
            descriptorID: descriptorID,
            continuation: continuation,
            progress: progressDetail,
            tracker: tracker
        )
    }

    private func publishDownloadProgressIfNeeded(
        descriptorID: ModelID,
        continuation: AsyncThrowingStream<ModelInstallEvent, Error>.Continuation,
        progress: ModelInstallProgress,
        tracker: DownloadProgressTracker,
        includeStateChange: Bool = false
    ) async throws {
        let clampedProgress = min(max(progress.fractionCompleted, 0), 1)
        let shouldPublishProgress = clampedProgress >= 1 || clampedProgress - tracker.lastReportedProgress >= 0.01
        if includeStateChange || shouldPublishProgress {
            await stateMachine.transition(modelID: descriptorID, to: .downloading(progress: clampedProgress))
        }
        if includeStateChange {
            continuation.yield(.stateChanged(descriptorID, .downloading(progress: clampedProgress)))
        }
        guard shouldPublishProgress else {
            return
        }

        tracker.lastReportedProgress = clampedProgress
        try? progressStore?.store(modelID: descriptorID, progress: progress)
        continuation.yield(.progress(descriptorID, clampedProgress))
        continuation.yield(.progressDetail(descriptorID, progress))
    }

    private func ensureLoadedPersistedRecords() async throws {
        guard !hasLoadedPersistedRecords, let recordStore else {
            return
        }

        let loadedRecords = try await recordStore.load()
        for record in loadedRecords {
            records[record.descriptor.id] = record
            await stateMachine.transition(modelID: record.descriptor.id, to: record.installState)
        }
        hasLoadedPersistedRecords = true
    }

    private func storageUsageWithoutLoading(for modelID: ModelID) throws -> Int64 {
        try progressStore?.storageUsage(for: modelID) ?? 0
    }

    private func diskUsageSnapshot() throws -> (availableBytes: Int64?, capacityBytes: Int64?) {
        try progressStore?.diskUsageSnapshot() ?? (nil, nil)
    }

    private static func mapInstallError(_ error: Error) -> LLMError {
        if let llmError = error as? LLMError {
            return llmError
        }
        if error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return .cancelled
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError {
            return .downloadFailed("A downloaded model file is missing. Retry the installation.")
        }
        if nsError.domain == NSURLErrorDomain, nsError.code == URLError.fileDoesNotExist.rawValue {
            return .downloadFailed("The remote artifact could not be resolved. Retry the installation.")
        }
        if nsError.domain == NSURLErrorDomain {
            return .downloadFailed(Self.networkDownloadMessage(for: nsError))
        }
        return .executionFailed("Installation failed. Retry the operation.")
    }

    private static func description(for error: LLMError) -> String {
        switch error {
        case .downloadFailed(let message),
             .verificationFailed(let message),
             .executionFailed(let message),
             .toolExecutionFailed(let message),
             .invalidStructuredOutput(let message):
            return message
        case .modelNotInstalled(let modelID):
            return "\(modelID.rawValue) is not installed."
        case .unsupportedCapabilities:
            return "Unsupported capabilities."
        case .unsupportedLocale(let message),
             .modelSelectionFailed(let message):
            return message
        case .cancelled:
            return "Cancelled."
        case .unavailable:
            return "Unavailable."
        case .compilationFailed:
            return "Compilation failed."
        }
    }

    private static func networkDownloadMessage(for error: NSError) -> String {
        switch URLError.Code(rawValue: error.code) {
        case .networkConnectionLost:
            return "Network connection was lost during model download. Retry the installation."
        case .timedOut:
            return "Model download timed out. Retry the installation."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return "Could not connect during model download. Retry the installation."
        case .notConnectedToInternet:
            return "No internet connection during model download."
        default:
            return "Model download failed. Retry the installation."
        }
    }

    private static func byteCountTitle(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
