import LLMCore

public protocol ModelCatalogProviding: Sendable {
    func availableModels() async throws -> [ModelDescriptor]
    func descriptor(for id: ModelID) async throws -> ModelDescriptor?
}

public protocol ModelManifestProviding: Sendable {
    func manifestModels() async throws -> [ModelDescriptor]
}

public protocol InstalledModelProviding: Sendable {
    func installedModels() async throws -> [InstalledModelRecord]
    func installedRecord(for id: ModelID) async throws -> InstalledModelRecord?
}
