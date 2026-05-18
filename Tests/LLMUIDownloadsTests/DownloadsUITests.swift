import Foundation
import LLMCore
import LLMModelLifecycle
import LLMProtocols
import LLMUIDownloads
import Testing

private struct InstallingLifecycleService: ModelLifecycleService {
    func installedModels() async throws -> [InstalledModelRecord] {
        []
    }

    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.progress(descriptor.id, 0.5))
            continuation.yield(.completed(InstalledModelRecord(descriptor: descriptor, installState: .ready)))
            continuation.finish()
        }
    }

    func state(for modelID: ModelID) async throws -> InstallState {
        .ready
    }
}

private struct FailingLifecycleService: ModelLifecycleService {
    func installedModels() async throws -> [InstalledModelRecord] {
        throw LLMError.unavailable
    }

    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.failed(descriptor.id, .downloadFailed("network")))
            continuation.finish()
        }
    }

    func state(for modelID: ModelID) async throws -> InstallState {
        throw LLMError.unavailable
    }
}

private struct ThrowingInstallLifecycleService: ModelLifecycleService {
    func installedModels() async throws -> [InstalledModelRecord] {
        []
    }

    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.stateChanged(descriptor.id, .downloading(progress: 0.1)))
            continuation.yield(.failed(descriptor.id, .downloadFailed("offline")))
            continuation.finish(throwing: LLMError.downloadFailed("offline"))
        }
    }

    func state(for modelID: ModelID) async throws -> InstallState {
        .notInstalled
    }
}

private struct RawNetworkErrorLifecycleService: ModelLifecycleService {
    func installedModels() async throws -> [InstalledModelRecord] {
        []
    }

    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.stateChanged(descriptor.id, .downloading(progress: 0.1)))
            continuation.finish(throwing: NSError(
                domain: NSURLErrorDomain,
                code: URLError.Code.networkConnectionLost.rawValue,
                userInfo: [
                    NSURLErrorFailingURLStringErrorKey: "https://cas-bridge.xethub.hf.co/private?X-Amz-Signature=secret",
                    "NSURLSessionDownloadTaskResumeData": Data("resume".utf8)
                ]
            ))
        }
    }

    func state(for modelID: ModelID) async throws -> InstallState {
        .notInstalled
    }
}

private struct RefreshingLifecycleService: ModelLifecycleService {
    let records: [InstalledModelRecord]

    func installedModels() async throws -> [InstalledModelRecord] {
        records
    }

    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func state(for modelID: ModelID) async throws -> InstallState {
        records.first { $0.descriptor.id == modelID }?.installState ?? .notInstalled
    }
}

private actor ViewModelDownloadLog {
    private(set) var started = false

    func recordStarted() {
        started = true
    }
}

private struct BlockingPartialArtifactDownloader: ModelArtifactDownloading {
    let partialData: Data
    let log: ViewModelDownloadLog

    func download(_ artifact: ModelArtifact, to destination: URL) async throws -> ModelArtifactDownloadResult {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try partialData.write(to: destination, options: [.atomic])
        try Data("resume".utf8).write(
            to: destination
                .deletingLastPathComponent()
                .appendingPathComponent(".\(destination.lastPathComponent).resumeData"),
            options: [.atomic]
        )
        await log.recordStarted()
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return ModelArtifactDownloadResult(artifactID: artifact.id, bytesWritten: Int64(partialData.count))
    }
}

private actor PartialMaintenanceLifecycleService: ModelLifecycleMaintenanceService {
    private let descriptor: ModelDescriptor
    private var state: InstallState
    private var partialBytes: Int64

    init(descriptor: ModelDescriptor, state: InstallState, partialBytes: Int64) {
        self.descriptor = descriptor
        self.state = state
        self.partialBytes = partialBytes
    }

    func installedModels() async throws -> [InstalledModelRecord] {
        []
    }

    nonisolated func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func state(for modelID: ModelID) async throws -> InstallState {
        modelID == descriptor.id ? state : .notInstalled
    }

    func deleteInstalledModel(_ modelID: ModelID) async throws {
        guard modelID == descriptor.id else {
            return
        }
        partialBytes = 0
        state = .notInstalled
    }

    func storageUsage() async throws -> ModelStorageUsage {
        .empty
    }

    func storageUsage(for modelID: ModelID) async throws -> Int64 {
        modelID == descriptor.id ? partialBytes : 0
    }
}

@MainActor
@Test func downloadsViewModelReplacesModels() {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel()

    viewModel.replaceModels([InstalledModelRecord(descriptor: descriptor, installState: .ready)])

    #expect(viewModel.models.count == 1)
}

@MainActor
@Test func downloadsViewModelInstallsThroughLifecycleService() async {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel(lifecycleService: InstallingLifecycleService())

    await viewModel.install(descriptor)

    #expect(viewModel.models.count == 1)
    #expect(viewModel.installStates[descriptor.id] == .ready)
}

@MainActor
@Test func downloadsViewModelReportsPresentationState() async {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel(models: [
        InstalledModelRecord(descriptor: descriptor, installState: .downloading(progress: 0.5))
    ])

    #expect(viewModel.statusText(for: descriptor.id) == "Downloading 50%")
    #expect(viewModel.progress(for: descriptor.id) == 0.5)
    #expect(!viewModel.isInstalled(descriptor.id))
    #expect(!viewModel.isInstallButtonDisabled(for: descriptor.id))
}

@MainActor
@Test func downloadsViewModelNormalizesPercentShapedProgress() {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel(models: [
        InstalledModelRecord(descriptor: descriptor, installState: .downloading(progress: 50))
    ])

    #expect(viewModel.statusText(for: descriptor.id) == "Downloading 50%")
    #expect(viewModel.progress(for: descriptor.id) == 0.5)
}

@MainActor
@Test func downloadsViewModelRefreshLoadsInstalledModels() async {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let record = InstalledModelRecord(descriptor: descriptor, installState: .active)
    let viewModel = ModelDownloadsViewModel(lifecycleService: RefreshingLifecycleService(records: [record]))

    await viewModel.refresh()

    #expect(viewModel.models == [record])
    #expect(viewModel.installStates[descriptor.id] == .active)
    #expect(viewModel.lastErrorMessage == nil)
}

@MainActor
@Test func downloadsViewModelRefreshStoresErrorMessageOnFailure() async {
    let viewModel = ModelDownloadsViewModel(lifecycleService: FailingLifecycleService())

    await viewModel.refresh()

    #expect(viewModel.lastErrorMessage == "Unavailable.")
}

@MainActor
@Test func downloadsViewModelInstallFailedEventUpdatesStateAndClearsInstallingFlag() async {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel(lifecycleService: FailingLifecycleService())

    await viewModel.install(descriptor)

    #expect(viewModel.installStates[descriptor.id] == .failed("network"))
    #expect(!viewModel.installingModelIDs.contains(descriptor.id))
    #expect(!viewModel.isInstallButtonDisabled(for: descriptor.id))
}

@MainActor
@Test func downloadsViewModelInstallThrowStoresErrorAndClearsInstallingFlag() async {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel(lifecycleService: ThrowingInstallLifecycleService())

    await viewModel.install(descriptor)

    #expect(viewModel.installStates[descriptor.id] == .failed("offline"))
    #expect(viewModel.lastErrorMessage == "offline")
    #expect(!viewModel.installingModelIDs.contains(descriptor.id))
}

@MainActor
@Test func downloadsViewModelRedactsRawNetworkErrors() async {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel(lifecycleService: RawNetworkErrorLifecycleService())

    await viewModel.install(descriptor)

    #expect(viewModel.lastErrorMessage == "Network connection was lost. Retry the installation.")
    #expect(viewModel.lastErrorMessage?.contains("X-Amz-Signature") == false)
    #expect(viewModel.lastErrorMessage?.contains("NSURLSessionDownloadTaskResumeData") == false)
}

@MainActor
@Test func downloadsViewModelReportsInstalledAndTerminalPresentationStates() {
    let ready = ModelID(rawValue: "ready")
    let warming = ModelID(rawValue: "warming")
    let active = ModelID(rawValue: "active")
    let failed = ModelID(rawValue: "failed")
    let evicted = ModelID(rawValue: "evicted")
    let viewModel = ModelDownloadsViewModel(models: [
        InstalledModelRecord(
            descriptor: ModelDescriptor(id: ready, displayName: "Ready", family: .custom("test"), backend: .coreML, capabilities: []),
            installState: .ready
        ),
        InstalledModelRecord(
            descriptor: ModelDescriptor(id: warming, displayName: "Warming", family: .custom("test"), backend: .coreML, capabilities: []),
            installState: .warming
        ),
        InstalledModelRecord(
            descriptor: ModelDescriptor(id: active, displayName: "Active", family: .custom("test"), backend: .coreML, capabilities: []),
            installState: .active
        ),
        InstalledModelRecord(
            descriptor: ModelDescriptor(id: failed, displayName: "Failed", family: .custom("test"), backend: .coreML, capabilities: []),
            installState: .failed("bad")
        ),
        InstalledModelRecord(
            descriptor: ModelDescriptor(id: evicted, displayName: "Evicted", family: .custom("test"), backend: .coreML, capabilities: []),
            installState: .evicted(.userRequested)
        )
    ])

    #expect(viewModel.isInstalled(ready))
    #expect(viewModel.isInstalled(warming))
    #expect(viewModel.isInstalled(active))
    #expect(!viewModel.isInstalled(failed))
    #expect(!viewModel.isInstalled(evicted))
    #expect(viewModel.isInstallButtonDisabled(for: ready))
    #expect(viewModel.statusText(for: failed) == "Failed: bad")
    #expect(viewModel.statusText(for: evicted) == "Evicted: userRequested")
}

@MainActor
@Test func downloadsViewModelReportsInProgressStates() {
    let modelID = ModelID(rawValue: "installing")
    let viewModel = ModelDownloadsViewModel(models: [
        InstalledModelRecord(
            descriptor: ModelDescriptor(id: modelID, displayName: "Installing", family: .custom("test"), backend: .coreML, capabilities: []),
            installState: .verifying
        )
    ])

    #expect(viewModel.isInstalling(modelID))
}

@MainActor
@Test func downloadsViewModelCancelInstallWaitsForCleanupAndClearsArtifacts() async throws {
    let partialData = Data("partial".utf8)
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMKitTests-\(UUID().uuidString)", isDirectory: true)
    let artifact = ModelArtifact(
        id: "weights",
        url: URL(string: "https://example.com/model.safetensors")!,
        relativePath: "model.safetensors",
        byteCount: 32
    )
    let descriptor = ModelDescriptor(
        id: "mlx/cancel-from-ui",
        displayName: "Cancel From UI",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/model",
            artifacts: [artifact]
        )
    )
    let log = ViewModelDownloadLog()
    let coordinator = ModelInstallCoordinator(
        artifactRootDirectory: rootDirectory,
        artifactDownloader: BlockingPartialArtifactDownloader(partialData: partialData, log: log),
        interruptionPolicy: ModelInstallInterruptionPolicy(cancellationBehavior: .removeAllArtifacts)
    )
    let viewModel = ModelDownloadsViewModel(
        descriptors: [descriptor],
        lifecycleService: coordinator
    )

    await viewModel.beginInstall(descriptor)
    for _ in 0..<100 {
        if await log.started {
            break
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(await log.started)
    #expect(viewModel.isInstallButtonDisabled(for: descriptor.id))

    await viewModel.cancelInstall(descriptor.id)

    let modelDirectory = ModelArtifactLocationResolver(rootDirectory: rootDirectory)
        .modelDirectory(for: descriptor.id)
    #expect(viewModel.installState(for: descriptor.id) == .notInstalled)
    #expect(!viewModel.installingModelIDs.contains(descriptor.id))
    #expect(!viewModel.cancelingModelIDs.contains(descriptor.id))
    #expect(!viewModel.isInstallButtonDisabled(for: descriptor.id))
    #expect(!FileManager.default.fileExists(atPath: modelDirectory.path))
    #expect((viewModel.storageBytes(for: descriptor.id) ?? 0) == 0)
}

@MainActor
@Test func failedPartialModelCanBeClearedWhileRetryStaysAvailable() async {
    let descriptor = ModelDescriptor(
        id: "failed-partial",
        displayName: "Failed Partial",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat]
    )
    let service = PartialMaintenanceLifecycleService(
        descriptor: descriptor,
        state: .failed("network"),
        partialBytes: 128
    )
    let viewModel = ModelDownloadsViewModel(
        descriptors: [descriptor],
        lifecycleService: service
    )

    await viewModel.refresh()

    #expect(viewModel.installState(for: descriptor.id) == .failed("network"))
    #expect(viewModel.storageBytes(for: descriptor.id) == 128)
    #expect(viewModel.canDeleteArtifacts(for: descriptor.id))
    #expect(!viewModel.isInstallButtonDisabled(for: descriptor.id))

    await viewModel.delete(descriptor.id)

    #expect(viewModel.installState(for: descriptor.id) == .notInstalled)
    #expect((viewModel.storageBytes(for: descriptor.id) ?? 0) == 0)
    #expect(!viewModel.canDeleteArtifacts(for: descriptor.id))
}
