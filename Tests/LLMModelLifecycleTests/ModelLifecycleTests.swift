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
