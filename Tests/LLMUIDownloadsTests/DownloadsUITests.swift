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
