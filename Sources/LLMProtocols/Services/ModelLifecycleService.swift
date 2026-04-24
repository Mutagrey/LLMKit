import LLMCore

public protocol ModelLifecycleService: Sendable {
    func installedModels() async throws -> [InstalledModelRecord]
    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error>
    func state(for modelID: ModelID) async throws -> InstallState
}

public protocol ModelLifecycleMaintenanceService: ModelLifecycleService {
    func deleteInstalledModel(_ modelID: ModelID) async throws
    func storageUsage() async throws -> ModelStorageUsage
    func storageUsage(for modelID: ModelID) async throws -> Int64
}
