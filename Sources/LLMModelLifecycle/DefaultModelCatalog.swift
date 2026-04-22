import LLMCore
import LLMProtocols

public actor DefaultModelCatalog: ModelCatalogProviding, ModelManifestProviding {
    private var descriptors: [ModelID: ModelDescriptor]

    public init(models: [ModelDescriptor] = []) {
        self.descriptors = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
    }

    public func register(_ descriptor: ModelDescriptor) {
        descriptors[descriptor.id] = descriptor
    }

    public func availableModels() async throws -> [ModelDescriptor] {
        Array(descriptors.values).sorted { $0.displayName < $1.displayName }
    }

    public func descriptor(for id: ModelID) async throws -> ModelDescriptor? {
        descriptors[id]
    }

    public func manifestModels() async throws -> [ModelDescriptor] {
        try await availableModels()
    }
}
