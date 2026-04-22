import LLMCore
import LLMUIDownloads
import Testing

@MainActor
@Test func downloadsViewModelReplacesModels() {
    let descriptor = ModelDescriptor(id: "model", displayName: "Model", family: .custom("test"), backend: .coreML, capabilities: [])
    let viewModel = ModelDownloadsViewModel()

    viewModel.replaceModels([InstalledModelRecord(descriptor: descriptor, installState: .ready)])

    #expect(viewModel.models.count == 1)
}
