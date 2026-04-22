import LLMCore

public protocol ModelLifecycleService: Sendable {
    func installedModels() async throws -> [InstalledModelRecord]
    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error>
    func state(for modelID: ModelID) async throws -> InstallState
}
