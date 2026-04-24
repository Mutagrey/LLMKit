import LLMCore

public protocol ModelCatalogStatusProviding: Sendable {
    func catalogStatus() async -> ModelCatalogStatus
}
