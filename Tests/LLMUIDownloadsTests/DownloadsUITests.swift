import LLMCore
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
            continuation.finish(throwing: LLMError.downloadFailed("offline"))
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

    #expect(viewModel.lastErrorMessage == "unavailable")
}

@MainActor
@Test func downloadsViewModelInstallFailedEventUpdatesStateAndClearsInstallingFlag() async {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel(lifecycleService: FailingLifecycleService())

    await viewModel.install(descriptor)

    #expect(viewModel.installStates[descriptor.id] == .failed("downloadFailed(\"network\")"))
    #expect(!viewModel.installingModelIDs.contains(descriptor.id))
    #expect(!viewModel.isInstallButtonDisabled(for: descriptor.id))
}

@MainActor
@Test func downloadsViewModelInstallThrowStoresErrorAndClearsInstallingFlag() async {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel(lifecycleService: ThrowingInstallLifecycleService())

    await viewModel.install(descriptor)

    #expect(viewModel.installStates[descriptor.id] == .downloading(progress: 0.1))
    #expect(viewModel.lastErrorMessage == "downloadFailed(\"offline\")")
    #expect(!viewModel.installingModelIDs.contains(descriptor.id))
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
