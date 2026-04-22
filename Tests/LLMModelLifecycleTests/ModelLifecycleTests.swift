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
