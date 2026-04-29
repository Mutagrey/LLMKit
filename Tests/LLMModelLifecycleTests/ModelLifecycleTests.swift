import CryptoKit
import Foundation
import LLMCore
import LLMModelLifecycle
import LLMProtocols
import Testing

private actor InMemoryManifestStore: ManifestStore {
    private var manifests: [String: Data] = [:]

    func loadManifest(named name: String) async throws -> Data? {
        manifests[name]
    }

    func saveManifest(_ data: Data, named name: String) async throws {
        manifests[name] = data
    }
}

private actor DownloadCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

private struct CorruptManifestStore: ManifestStore {
    func loadManifest(named name: String) async throws -> Data? {
        Data("{not-json".utf8)
    }

    func saveManifest(_ data: Data, named name: String) async throws {}
}

private struct WritingArtifactDownloader: ModelArtifactDownloading {
    let data: Data

    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: [.atomic])
        return ModelArtifactDownloadResult(artifactID: artifact.id, bytesWritten: Int64(data.count))
    }
}

private struct CountingArtifactDownloader: ModelArtifactDownloading {
    let data: Data
    let counter: DownloadCounter

    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        await counter.increment()
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: [.atomic])
        return ModelArtifactDownloadResult(artifactID: artifact.id, bytesWritten: Int64(data.count))
    }
}

private struct ProgressReportingArtifactDownloader: ProgressReportingModelArtifactDownloading {
    let expectedByteCount: Int64
    let checkpoints: [Int64]

    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        try await download(artifact, to: destination) { _ in }
    }

    func download(
        _ artifact: ModelArtifact,
        to destination: URL,
        onProgress: @escaping @Sendable (ModelArtifactDownloadProgress) async -> Void
    ) async throws -> ModelArtifactDownloadResult {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = Data(repeating: 0x61, count: Int(expectedByteCount))
        try data.write(to: destination, options: [.atomic])
        for checkpoint in checkpoints {
            await onProgress(ModelArtifactDownloadProgress(
                artifactID: artifact.id,
                bytesWritten: checkpoint,
                expectedTotalBytes: expectedByteCount
            ))
        }
        return ModelArtifactDownloadResult(artifactID: artifact.id, bytesWritten: expectedByteCount)
    }
}

private actor DownloadedArtifactLog {
    private(set) var artifactIDs: [String] = []

    func record(_ artifactID: String) {
        artifactIDs.append(artifactID)
    }

    func snapshot() -> [String] {
        artifactIDs
    }
}

private struct CancellationAwareArtifactDownloader: ModelArtifactDownloading {
    let payloadsByArtifactID: [String: Data]
    let log: DownloadedArtifactLog

    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        try Task.checkCancellation()

        guard let data = payloadsByArtifactID[artifact.id] else {
            throw LLMError.downloadFailed("Missing test payload for \(artifact.id).")
        }

        if artifact.id == "tokenizer" {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        try Task.checkCancellation()

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: [.atomic])
        await log.record(artifact.id)

        return ModelArtifactDownloadResult(artifactID: artifact.id, bytesWritten: Int64(data.count))
    }
}

@Test func modelInstallCoordinatorPublishesReadyRecord() async throws {
    let descriptor = ModelDescriptor(
        id: "local-model",
        displayName: "Local Model",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let coordinator = ModelInstallCoordinator()

    var events: [ModelInstallEvent] = []
    for try await event in coordinator.install(descriptor) {
        events.append(event)
    }

    #expect(events.count == 2)
    #expect(try await coordinator.state(for: descriptor.id) == .ready)
}

@Test func modelInstallCoordinatorDownloadsDeclaredArtifactsBeforeReady() async throws {
    let artifactData = Data("weights".utf8)
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen-test",
        displayName: "Qwen Test",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            artifacts: [
                ModelArtifact(
                    id: "config",
                    url: URL(string: "https://example.com/config.json")!,
                    relativePath: "config.json",
                    byteCount: Int64(artifactData.count)
                )
            ]
        )
    )
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: WritingArtifactDownloader(data: artifactData)
    )

    var events: [ModelInstallEvent] = []
    for try await event in coordinator.install(descriptor) {
        events.append(event)
    }

    let destination = rootDirectory
        .appendingPathComponent("mlx_qwen-test", isDirectory: true)
        .appendingPathComponent("config.json")
    #expect(FileManager.default.fileExists(atPath: destination.path))
    #expect(try Data(contentsOf: destination) == artifactData)
    #expect(events.contains(.progress(descriptor.id, 1)))
    #expect(events.contains(.stateChanged(descriptor.id, .verifying)))
    #expect(try await coordinator.state(for: descriptor.id) == .ready)
}

@Test func modelInstallCoordinatorUsesStreamingByteProgressWhenAvailable() async throws {
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen-streaming-progress",
        displayName: "Qwen Streaming Progress",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors"
                )
            ]
        ),
        estimatedDownloadSizeBytes: 100
    )
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: ProgressReportingArtifactDownloader(
            expectedByteCount: 100,
            checkpoints: [20, 55, 100]
        )
    )

    var progressValues: [Double] = []
    for try await event in coordinator.install(descriptor) {
        if case .progress(_, let progress) = event {
            progressValues.append(progress)
        }
    }

    #expect(progressValues.contains(0.2))
    #expect(progressValues.contains(0.55))
    #expect(progressValues.contains(1))
}

@Test func modelInstallCoordinatorReusesValidExistingArtifactsOnRetry() async throws {
    let artifactData = Data("weights".utf8)
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen-resume",
        displayName: "Qwen Resume",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    byteCount: Int64(artifactData.count),
                    checksum: ModelArtifactChecksum(
                        algorithm: "sha256",
                        value: SHA256.hash(data: artifactData).map { String(format: "%02x", $0) }.joined()
                    )
                )
            ]
        )
    )
    let counter = DownloadCounter()
    let primingCoordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: WritingArtifactDownloader(data: artifactData)
    )
    for try await _ in primingCoordinator.install(descriptor) {}

    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: CountingArtifactDownloader(data: artifactData, counter: counter)
    )

    for try await _ in coordinator.install(descriptor) {}

    #expect(await counter.count == 0)
}

@Test func modelInstallCoordinatorRedownloadsInvalidExistingArtifactsOnRetry() async throws {
    let validData = Data("valid-weights".utf8)
    let invalidData = Data("bad".utf8)
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen-redownload",
        displayName: "Qwen Redownload",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    byteCount: Int64(validData.count),
                    checksum: ModelArtifactChecksum(
                        algorithm: "sha256",
                        value: SHA256.hash(data: validData).map { String(format: "%02x", $0) }.joined()
                    )
                )
            ]
        )
    )
    let resolver = ModelArtifactLocationResolver(rootDirectory: rootDirectory)
    let invalidURL = try resolver.artifactURL(modelID: descriptor.id, artifact: descriptor.source!.artifacts[0])
    try FileManager.default.createDirectory(
        at: invalidURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try invalidData.write(to: invalidURL, options: [.atomic])

    let counter = DownloadCounter()
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: CountingArtifactDownloader(data: validData, counter: counter)
    )

    for try await _ in coordinator.install(descriptor) {}

    #expect(await counter.count == 1)
    #expect(try Data(contentsOf: invalidURL) == validData)
}

@Test func urlSessionArtifactDownloaderMovesDownloadedFileIntoDestination() async throws {
    let sourceData = Data("local-model-artifact".utf8)
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let sourceURL = rootDirectory.appendingPathComponent("source.safetensors")
    let destinationURL = rootDirectory
        .appendingPathComponent("Artifacts", isDirectory: true)
        .appendingPathComponent("model.safetensors")

    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    try sourceData.write(to: sourceURL, options: [.atomic])

    let artifact = ModelArtifact(
        id: "weights",
        url: sourceURL,
        relativePath: "model.safetensors"
    )
    let result = try await URLSessionModelArtifactDownloader().download(artifact, to: destinationURL)

    #expect(result.artifactID == "weights")
    #expect(result.bytesWritten == Int64(sourceData.count))
    #expect(try Data(contentsOf: destinationURL) == sourceData)
}

@Test func cancelledInstallPreservesVerifiedArtifactsForResumeByDefault() async throws {
    let weightsData = Data("weights".utf8)
    let tokenizerData = Data("tokenizer".utf8)
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen-cancel-resume",
        displayName: "Qwen Cancel Resume",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    byteCount: Int64(weightsData.count),
                    checksum: ModelArtifactChecksum(
                        algorithm: "sha256",
                        value: SHA256.hash(data: weightsData).map { String(format: "%02x", $0) }.joined()
                    )
                ),
                ModelArtifact(
                    id: "tokenizer",
                    url: URL(string: "https://example.com/tokenizer.json")!,
                    relativePath: "tokenizer.json",
                    byteCount: Int64(tokenizerData.count),
                    checksum: ModelArtifactChecksum(
                        algorithm: "sha256",
                        value: SHA256.hash(data: tokenizerData).map { String(format: "%02x", $0) }.joined()
                    )
                )
            ]
        )
    )
    let firstLog = DownloadedArtifactLog()
    let firstCoordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: CancellationAwareArtifactDownloader(
            payloadsByArtifactID: [
                "weights": weightsData,
                "tokenizer": tokenizerData
            ],
            log: firstLog
        )
    )

    let installTask = Task {
        for try await _ in firstCoordinator.install(descriptor) {}
    }
    while await firstLog.snapshot().isEmpty {
        await Task.yield()
    }
    installTask.cancel()
    _ = await installTask.result

    let resolver = ModelArtifactLocationResolver(rootDirectory: rootDirectory)
    let weightsURL = try resolver.artifactURL(modelID: descriptor.id, artifact: descriptor.source!.artifacts[0])
    let tokenizerURL = try resolver.artifactURL(modelID: descriptor.id, artifact: descriptor.source!.artifacts[1])

    #expect(FileManager.default.fileExists(atPath: weightsURL.path))
    #expect(!FileManager.default.fileExists(atPath: tokenizerURL.path))

    let secondLog = DownloadedArtifactLog()
    let secondCoordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: CancellationAwareArtifactDownloader(
            payloadsByArtifactID: [
                "weights": weightsData,
                "tokenizer": tokenizerData
            ],
            log: secondLog
        )
    )

    for try await _ in secondCoordinator.install(descriptor) {}

    #expect(await secondLog.snapshot() == ["tokenizer"])
}

@Test func cancelledInstallCanRemoveArtifactsWhenPolicyRequestsCleanup() async throws {
    let weightsData = Data("weights".utf8)
    let tokenizerData = Data("tokenizer".utf8)
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen-cancel-cleanup",
        displayName: "Qwen Cancel Cleanup",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    byteCount: Int64(weightsData.count),
                    checksum: ModelArtifactChecksum(
                        algorithm: "sha256",
                        value: SHA256.hash(data: weightsData).map { String(format: "%02x", $0) }.joined()
                    )
                ),
                ModelArtifact(
                    id: "tokenizer",
                    url: URL(string: "https://example.com/tokenizer.json")!,
                    relativePath: "tokenizer.json",
                    byteCount: Int64(tokenizerData.count),
                    checksum: ModelArtifactChecksum(
                        algorithm: "sha256",
                        value: SHA256.hash(data: tokenizerData).map { String(format: "%02x", $0) }.joined()
                    )
                )
            ]
        )
    )
    let log = DownloadedArtifactLog()
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: CancellationAwareArtifactDownloader(
            payloadsByArtifactID: [
                "weights": weightsData,
                "tokenizer": tokenizerData
            ],
            log: log
        ),
        interruptionPolicy: ModelInstallInterruptionPolicy(cancellationBehavior: .removeAllArtifacts)
    )

    let installTask = Task {
        for try await _ in coordinator.install(descriptor) {}
    }
    while await log.snapshot().isEmpty {
        await Task.yield()
    }
    installTask.cancel()
    _ = await installTask.result

    let modelDirectory = ModelArtifactLocationResolver(rootDirectory: rootDirectory)
        .modelDirectory(for: descriptor.id)
    for _ in 0..<20 where FileManager.default.fileExists(atPath: modelDirectory.path) {
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(!FileManager.default.fileExists(atPath: modelDirectory.path))
}

@Test func modelInstallCoordinatorFailsVerificationWhenArtifactChecksumMismatches() async throws {
    let artifactData = Data("weights".utf8)
    let expectedChecksum = SHA256.hash(data: Data("other-weights".utf8))
        .map { String(format: "%02x", $0) }
        .joined()
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "mlx/qwen-checksum-failure",
        displayName: "Qwen Checksum Failure",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "mlx-community/Qwen3-0.6B-4bit",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    byteCount: Int64(artifactData.count),
                    checksum: ModelArtifactChecksum(algorithm: "sha256", value: expectedChecksum)
                )
            ]
        )
    )
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: WritingArtifactDownloader(data: artifactData)
    )

    var events: [ModelInstallEvent] = []

    do {
        for try await event in coordinator.install(descriptor) {
            events.append(event)
        }
        Issue.record("Expected install to fail checksum verification.")
    } catch let error as LLMError {
        #expect(error == .verificationFailed("Artifact checksum mismatch for model.safetensors."))
    }

    #expect(events.contains(.stateChanged(descriptor.id, .verifying)))
    #expect(events.contains(.failed(descriptor.id, .verificationFailed("Artifact checksum mismatch for model.safetensors."))))
    #expect(try await coordinator.state(for: descriptor.id) == .failed("Artifact checksum mismatch for model.safetensors."))
}

@Test func modelInstallCoordinatorRequiresArtifactRootForDownloadableModels() async throws {
    let descriptor = ModelDescriptor(
        id: "downloadable",
        displayName: "Downloadable",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors"
                )
            ]
        )
    )
    let coordinator = ModelInstallCoordinator()

    do {
        for try await _ in coordinator.install(descriptor) {}
        Issue.record("Expected install to fail without an artifact root directory.")
    } catch {
        #expect(String(describing: error).contains("No artifact root directory configured"))
    }
}

@Test func installStateMachineDefaultsToNotInstalledAndIsolatesModels() async {
    let first: ModelID = "first-model"
    let second: ModelID = "second-model"
    let stateMachine = InstallStateMachine()

    #expect(await stateMachine.state(for: first) == .notInstalled)

    await stateMachine.transition(modelID: first, to: .downloading(progress: 0.5))

    #expect(await stateMachine.state(for: first) == .downloading(progress: 0.5))
    #expect(await stateMachine.state(for: second) == .notInstalled)
}

@Test func modelInstallCoordinatorReturnsInstalledModelsSortedByDisplayName() async throws {
    let zModel = ModelDescriptor(
        id: "z-model",
        displayName: "Z Model",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let aModel = ModelDescriptor(
        id: "a-model",
        displayName: "A Model",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let coordinator = ModelInstallCoordinator()

    for try await _ in coordinator.install(zModel) {}
    for try await _ in coordinator.install(aModel) {}

    let installed = try await coordinator.installedModels()

    #expect(installed.map(\.descriptor.id) == [aModel.id, zModel.id])
}

@Test func modelInstallCoordinatorPersistsInstalledRecords() async throws {
    let descriptor = ModelDescriptor(
        id: "persisted-model",
        displayName: "Persisted Model",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let store = InstalledModelRecordStore(manifestStore: InMemoryManifestStore())
    let coordinator = ModelInstallCoordinator(recordStore: store)

    for try await _ in coordinator.install(descriptor) {}

    let restored = try await ModelInstallCoordinator.persisted(recordStore: store)
    let record = try await restored.installedRecord(for: descriptor.id)

    #expect(record?.descriptor.id == descriptor.id)
    #expect(record?.installState == .ready)
}

@Test func persistedModelInstallCoordinatorRestoresInstallState() async throws {
    let descriptor = ModelDescriptor(
        id: "persisted-state-model",
        displayName: "Persisted State Model",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let store = InstalledModelRecordStore(manifestStore: InMemoryManifestStore())
    try await store.save([
        InstalledModelRecord(descriptor: descriptor, installState: .active)
    ])

    let restored = try await ModelInstallCoordinator.persisted(recordStore: store)

    #expect(try await restored.state(for: descriptor.id) == .active)
}

@Test func modelInstallCoordinatorLazilyRestoresPersistedRecords() async throws {
    let descriptor = ModelDescriptor(
        id: "lazy-persisted-model",
        displayName: "Lazy Persisted Model",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let store = InstalledModelRecordStore(manifestStore: InMemoryManifestStore())
    try await store.save([
        InstalledModelRecord(descriptor: descriptor, installState: .ready)
    ])
    let coordinator = ModelInstallCoordinator(recordStore: store)

    #expect(try await coordinator.state(for: descriptor.id) == .ready)
    #expect(try await coordinator.installedModels().map(\.descriptor.id) == [descriptor.id])
}

@Test func modelInstallCoordinatorDeletesInstalledModelAndStorage() async throws {
    let artifactData = Data("weights".utf8)
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let descriptor = ModelDescriptor(
        id: "delete/model",
        displayName: "Delete Model",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    byteCount: Int64(artifactData.count)
                )
            ]
        )
    )
    let store = InstalledModelRecordStore(manifestStore: InMemoryManifestStore())
    let coordinator = ModelInstallCoordinator(
        recordStore: store,
        artifactRootDirectory: rootDirectory,
        artifactDownloader: WritingArtifactDownloader(data: artifactData)
    )

    for try await _ in coordinator.install(descriptor) {}

    let usage = try await coordinator.storageUsage()
    #expect(usage.totalBytes == Int64(artifactData.count))
    #expect(try await coordinator.storageUsage(for: descriptor.id) == Int64(artifactData.count))

    try await coordinator.deleteInstalledModel(descriptor.id)

    #expect(try await coordinator.state(for: descriptor.id) == .notInstalled)
    #expect(try await coordinator.installedModels().isEmpty)
    #expect(try await coordinator.storageUsage().totalBytes == 0)
}

@Test func installedModelRecordStorePersistsRecordsSortedByDisplayName() async throws {
    let zModel = ModelDescriptor(
        id: "z-model",
        displayName: "Z Model",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let aModel = ModelDescriptor(
        id: "a-model",
        displayName: "A Model",
        family: .custom("test"),
        backend: .coreML,
        capabilities: [.completion]
    )
    let store = InstalledModelRecordStore(manifestStore: InMemoryManifestStore())

    try await store.save([
        InstalledModelRecord(descriptor: zModel, installState: .ready),
        InstalledModelRecord(descriptor: aModel, installState: .ready)
    ])

    let loaded = try await store.load()

    #expect(loaded.map(\.descriptor.id) == [aModel.id, zModel.id])
}

@Test func installedModelRecordStoreSurfacesCorruptManifestErrors() async throws {
    let store = InstalledModelRecordStore(manifestStore: CorruptManifestStore())

    do {
        _ = try await store.load()
        Issue.record("Expected corrupt installed model manifest to fail decoding.")
    } catch {
        #expect(error is DecodingError)
    }
}

@Test func manifestLoaderRoundTripsManifestThroughStore() async throws {
    let manifest = CuratedModelManifests.localIPhoneTextModels
    let store = InMemoryManifestStore()
    let loader = ManifestLoader()

    try await loader.save(manifest, named: "catalog.json", to: store)
    let restored = try await loader.load(named: "catalog.json", from: store)

    #expect(restored?.id == manifest.id)
    #expect(restored?.models.map(\.id) == manifest.models.map(\.id))
}

@Test func manifestLoaderVerifiesExpectedSignature() throws {
    let manifest = CuratedModelManifests.localIPhoneTextModels
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let signature = ModelManifestSignature(
        algorithm: "sha256",
        value: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    )

    let restored = try loader.load(data: data, expectedSignature: signature)

    #expect(restored.id == manifest.id)
    #expect(restored.models.map(\.id) == manifest.models.map(\.id))
}

@Test func manifestLoaderVerifiesEd25519ManifestSignature() throws {
    let manifest = CuratedModelManifests.localIPhoneTextModels
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let privateKey = Curve25519.Signing.PrivateKey()
    let signatureData = try privateKey.signature(for: data)
    let signature = ModelManifestSignature(
        algorithm: "ed25519",
        value: hexString(for: signatureData),
        publicKeyValue: hexString(for: privateKey.publicKey.rawRepresentation)
    )

    let restored = try loader.load(data: data, expectedSignature: signature)

    #expect(restored.id == manifest.id)
}

@Test func manifestLoaderRejectsInvalidExpectedSignature() throws {
    let manifest = CuratedModelManifests.localIPhoneTextModels
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)

    #expect(throws: LLMError.verificationFailed("Manifest signature mismatch.")) {
        try loader.load(
            data: data,
            expectedSignature: ModelManifestSignature(algorithm: "sha256", value: String(repeating: "0", count: 64))
        )
    }
}

@Test func defaultModelCatalogRegistersManifestContents() async throws {
    let manifest = CuratedModelManifests.localIPhoneTextModels
    let catalog = DefaultModelCatalog()

    await catalog.register(contentsOf: manifest)

    let models = try await catalog.availableModels()
    #expect(models.map(\.id) == manifest.models.sorted { $0.displayName < $1.displayName }.map(\.id))
}

@Test func dynamicModelCatalogUsesSignedRemoteManifestWhenValid() async throws {
    let descriptor = downloadableDescriptor(
        id: "remote-valid",
        checksum: SHA256.hash(data: Data("weights".utf8)).map { String(format: "%02x", $0) }.joined()
    )
    let manifest = ModelManifest(id: "remote", models: [descriptor])
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let privateKey = Curve25519.Signing.PrivateKey()
    let signatureData = try privateKey.signature(for: data)
    let catalog = DynamicModelCatalog(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: hexString(for: signatureData),
                publicKeyValue: hexString(for: privateKey.publicKey.rawRepresentation)
            )
        ),
        fallbackCatalog: DefaultModelCatalog(models: []),
        fetchManifestData: { _ in data }
    )

    let models = try await catalog.availableModels()

    #expect(models.map(\.id) == [descriptor.id])
}

@Test func dynamicModelCatalogFallsBackWhenRemoteHostIsNotAllowlisted() async throws {
    let fallback = ModelDescriptor(
        id: "fallback-host",
        displayName: "Fallback Host",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.chat]
    )
    let descriptor = downloadableDescriptor(
        id: "remote-host-blocked",
        checksum: SHA256.hash(data: Data("weights".utf8)).map { String(format: "%02x", $0) }.joined()
    )
    let manifest = ModelManifest(id: "remote", models: [descriptor])
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let privateKey = Curve25519.Signing.PrivateKey()
    let signatureData = try privateKey.signature(for: data)
    let catalog = DynamicModelCatalog(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://blocked.example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: hexString(for: signatureData),
                publicKeyValue: hexString(for: privateKey.publicKey.rawRepresentation)
            ),
            trustPolicy: RemoteManifestTrustPolicy(
                allowedHosts: ["catalog.example.com"]
            )
        ),
        fallbackCatalog: DefaultModelCatalog(models: [fallback]),
        fetchManifestData: { _ in data }
    )

    let models = try await catalog.availableModels()

    #expect(models.map(\.id) == [fallback.id])
}

@Test func dynamicModelCatalogAcceptsAnyTrustedSigningKeyFromRotationSet() async throws {
    let descriptor = downloadableDescriptor(
        id: "remote-rotated-key",
        checksum: SHA256.hash(data: Data("weights".utf8)).map { String(format: "%02x", $0) }.joined()
    )
    let manifest = ModelManifest(id: "remote", models: [descriptor])
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let activeKey = Curve25519.Signing.PrivateKey()
    let standbyKey = Curve25519.Signing.PrivateKey()
    let signatureData = try activeKey.signature(for: data)
    let catalog = DynamicModelCatalog(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://catalog.example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: hexString(for: signatureData),
                publicKeyValue: hexString(for: activeKey.publicKey.rawRepresentation)
            ),
            trustPolicy: RemoteManifestTrustPolicy(
                allowedHosts: ["catalog.example.com"],
                trustedSigningPublicKeys: [
                    hexString(for: standbyKey.publicKey.rawRepresentation),
                    hexString(for: activeKey.publicKey.rawRepresentation)
                ]
            )
        ),
        fallbackCatalog: DefaultModelCatalog(models: []),
        fetchManifestData: { _ in data }
    )

    let models = try await catalog.availableModels()

    #expect(models.map(\.id) == [descriptor.id])
}

@Test func dynamicModelCatalogFallsBackWhenSigningKeyIsNotTrusted() async throws {
    let fallback = ModelDescriptor(
        id: "fallback-key",
        displayName: "Fallback Key",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.chat]
    )
    let descriptor = downloadableDescriptor(
        id: "remote-untrusted-key",
        checksum: SHA256.hash(data: Data("weights".utf8)).map { String(format: "%02x", $0) }.joined()
    )
    let manifest = ModelManifest(id: "remote", models: [descriptor])
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let activeKey = Curve25519.Signing.PrivateKey()
    let untrustedKey = Curve25519.Signing.PrivateKey()
    let signatureData = try activeKey.signature(for: data)
    let catalog = DynamicModelCatalog(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://catalog.example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: hexString(for: signatureData),
                publicKeyValue: hexString(for: activeKey.publicKey.rawRepresentation)
            ),
            trustPolicy: RemoteManifestTrustPolicy(
                allowedHosts: ["catalog.example.com"],
                trustedSigningPublicKeys: [hexString(for: untrustedKey.publicKey.rawRepresentation)]
            )
        ),
        fallbackCatalog: DefaultModelCatalog(models: [fallback]),
        fetchManifestData: { _ in data }
    )

    let models = try await catalog.availableModels()

    #expect(models.map(\.id) == [fallback.id])
}

@Test func dynamicModelCatalogFallsBackWhenRemoteSignatureFails() async throws {
    let fallback = ModelDescriptor(
        id: "fallback",
        displayName: "Fallback",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.chat]
    )
    let manifest = ModelManifest(id: "remote", models: [
        downloadableDescriptor(id: "remote-invalid", checksum: "invalid")
    ])
    let data = try ManifestLoader().encoded(manifest)
    let catalog = DynamicModelCatalog(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: String(repeating: "0", count: 128),
                publicKeyValue: hexString(for: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation)
            )
        ),
        fallbackCatalog: DefaultModelCatalog(models: [fallback]),
        fetchManifestData: { _ in data }
    )

    let models = try await catalog.availableModels()

    #expect(models.map(\.id) == [fallback.id])
}

@Test func dynamicModelCatalogFallsBackWhenRemoteArtifactLacksChecksum() async throws {
    let fallback = ModelDescriptor(
        id: "fallback",
        displayName: "Fallback",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.chat]
    )
    let manifest = ModelManifest(id: "remote", models: [
        downloadableDescriptor(id: "remote-missing-checksum", checksum: nil)
    ])
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let privateKey = Curve25519.Signing.PrivateKey()
    let signatureData = try privateKey.signature(for: data)
    let catalog = DynamicModelCatalog(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: hexString(for: signatureData),
                publicKeyValue: hexString(for: privateKey.publicKey.rawRepresentation)
            )
        ),
        fallbackCatalog: DefaultModelCatalog(models: [fallback]),
        fetchManifestData: { _ in data }
    )

    let models = try await catalog.availableModels()

    #expect(models.map(\.id) == [fallback.id])
}

@Test func dynamicModelCatalogReportsRemoteVerifiedStatusAfterSuccessfulFetch() async throws {
    let descriptor = downloadableDescriptor(
        id: "remote-status-valid",
        checksum: SHA256.hash(data: Data("weights".utf8)).map { String(format: "%02x", $0) }.joined()
    )
    let manifest = ModelManifest(id: "remote", models: [descriptor])
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let privateKey = Curve25519.Signing.PrivateKey()
    let signatureData = try privateKey.signature(for: data)
    let catalog = DynamicModelCatalog(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: hexString(for: signatureData),
                publicKeyValue: hexString(for: privateKey.publicKey.rawRepresentation)
            )
        ),
        fallbackCatalog: DefaultModelCatalog(models: []),
        fetchManifestData: { _ in data }
    )

    _ = try await catalog.availableModels()
    let status = await catalog.catalogStatus()

    #expect(status.source == .remoteVerified)
    #expect(status.message == "example.com")
}

@Test func dynamicModelCatalogReportsFallbackStatusAfterVerificationFailure() async throws {
    let fallback = ModelDescriptor(
        id: "fallback-status",
        displayName: "Fallback Status",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [.chat]
    )
    let manifest = ModelManifest(id: "remote", models: [
        downloadableDescriptor(id: "remote-invalid-status", checksum: "invalid")
    ])
    let data = try ManifestLoader().encoded(manifest)
    let catalog = DynamicModelCatalog(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: String(repeating: "0", count: 128),
                publicKeyValue: hexString(for: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation)
            )
        ),
        fallbackCatalog: DefaultModelCatalog(models: [fallback]),
        fetchManifestData: { _ in data }
    )

    _ = try await catalog.availableModels()
    let status = await catalog.catalogStatus()

    #expect(status.source == .fallback)
    #expect(status.message?.contains("Manifest signature mismatch") == true)
}

private func downloadableDescriptor(id: ModelID, checksum: String?) -> ModelDescriptor {
    ModelDescriptor(
        id: id,
        displayName: id.rawValue,
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat, .completion, .streaming, .offline],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    checksum: checksum.map { ModelArtifactChecksum(algorithm: "sha256", value: $0) }
                )
            ]
        )
    )
}

private func hexString(for data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}
