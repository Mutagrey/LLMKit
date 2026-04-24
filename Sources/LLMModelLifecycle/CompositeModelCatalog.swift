import LLMCore
import LLMProtocols

public actor CompositeModelCatalog: ModelCatalogProviding, ModelManifestProviding {
    private let catalogs: [any ModelCatalogProviding]

    public init(catalogs: [any ModelCatalogProviding]) {
        self.catalogs = catalogs
    }

    public func availableModels() async throws -> [ModelDescriptor] {
        var descriptors: [ModelID: ModelDescriptor] = [:]
        for catalog in catalogs {
            for descriptor in try await catalog.availableModels() {
                descriptors[descriptor.id] = descriptor
            }
        }
        return descriptors.values.sorted { $0.displayName < $1.displayName }
    }

    public func descriptor(for id: ModelID) async throws -> ModelDescriptor? {
        for catalog in catalogs {
            if let descriptor = try await catalog.descriptor(for: id) {
                return descriptor
            }
        }
        return nil
    }

    public func manifestModels() async throws -> [ModelDescriptor] {
        try await availableModels()
    }
}
