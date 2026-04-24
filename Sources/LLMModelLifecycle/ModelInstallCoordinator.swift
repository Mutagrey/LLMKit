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
    private var hasLoadedPersistedRecords: Bool

    public init(
        records: [InstalledModelRecord] = [],
        stateMachine: InstallStateMachine? = nil,
        recordStore: InstalledModelRecordStore? = nil,
        artifactRootDirectory: URL? = nil,
        artifactDownloader: any ModelArtifactDownloading = URLSessionModelArtifactDownloader(),
        integrityVerifier: ModelIntegrityVerifier = ModelIntegrityVerifier(),
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
        return await stateMachine.state(for: modelID)
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
        return ModelStorageUsage(
            totalBytes: modelBytes.values.reduce(0, +),
            modelBytes: modelBytes
        )
    }

    public func storageUsage(for modelID: ModelID) async throws -> Int64 {
        try await ensureLoadedPersistedRecords()
        return try storageUsageWithoutLoading(for: modelID)
    }

    public nonisolated func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let record = try await completeInstall(descriptor, continuation: continuation)
                    continuation.yield(.stateChanged(descriptor.id, .ready))
                    continuation.yield(.completed(record))
                    continuation.finish()
                } catch {
                    let llmError = Self.mapInstallError(error)
                    await stateMachine.transition(modelID: descriptor.id, to: .failed(Self.description(for: llmError)))
                    continuation.yield(.failed(descriptor.id, llmError))
                    continuation.finish(throwing: llmError)
                }
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

        await stateMachine.transition(modelID: descriptor.id, to: .downloading(progress: 0))
        continuation.yield(.stateChanged(descriptor.id, .downloading(progress: 0)))

        let usesByteProgress = source.artifacts.allSatisfy { $0.byteCount != nil }
        let totalUnits = expectedProgressUnits(for: source.artifacts)
        var completedUnits: Int64 = 0

        for artifact in source.artifacts {
            let destination = try ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
                .artifactURL(modelID: descriptor.id, artifact: artifact)
            let result = try await artifactDownloader.download(artifact, to: destination)
            completedUnits += usesByteProgress ? (artifact.byteCount ?? result.bytesWritten) : 1
            let progress = min(Double(completedUnits) / Double(totalUnits), 1)
            await stateMachine.transition(modelID: descriptor.id, to: .downloading(progress: progress))
            continuation.yield(.progress(descriptor.id, progress))
        }

        await stateMachine.transition(modelID: descriptor.id, to: .verifying)
        continuation.yield(.stateChanged(descriptor.id, .verifying))
    }

    private func verifyArtifacts(
        for descriptor: ModelDescriptor,
        continuation: AsyncThrowingStream<ModelInstallEvent, Error>.Continuation
    ) async throws {
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

    private func expectedProgressUnits(for artifacts: [ModelArtifact]) -> Int64 {
        let knownBytes = artifacts.compactMap(\.byteCount)
        let total = knownBytes.reduce(Int64(0), +)
        if knownBytes.count == artifacts.count, total > 0 {
            return total
        }
        return Int64(max(artifacts.count, 1))
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
        guard let artifactRootDirectory else {
            return 0
        }

        let directory = ModelArtifactLocationResolver(rootDirectory: artifactRootDirectory)
            .modelDirectory(for: modelID)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return 0
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private static func mapInstallError(_ error: Error) -> LLMError {
        if let llmError = error as? LLMError {
            return llmError
        }
        if error is CancellationError {
            return .cancelled
        }
        return .executionFailed(String(describing: error))
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
        case .cancelled:
            return "Cancelled."
        case .unavailable:
            return "Unavailable."
        case .compilationFailed:
            return "Compilation failed."
        }
    }
}
