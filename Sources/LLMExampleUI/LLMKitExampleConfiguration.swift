import LLMBackendFoundationModels
import LLMCore
import LLMModelLifecycle
import LLMOrchestrator
import LLMProtocols

public struct LLMKitExampleConfiguration: Sendable {
    public let container: LLMKitContainer
    public let catalog: any ModelCatalogProviding
    public let backends: [any ModelBackend]
    public let downloadableModels: [ModelDescriptor]

    public init(
        container: LLMKitContainer,
        catalog: any ModelCatalogProviding,
        backends: [any ModelBackend],
        downloadableModels: [ModelDescriptor] = []
    ) {
        self.container = container
        self.catalog = catalog
        self.backends = backends
        self.downloadableModels = downloadableModels
    }

    public static func appleIntelligenceOnly(
        downloadableModels: [ModelDescriptor] = []
    ) -> LLMKitExampleConfiguration {
        let models = [LLMKitExampleModels.appleIntelligence] + downloadableModels
        let catalog = DefaultModelCatalog(models: models)
        let foundationModelsBackend = FoundationModelsBackend()
        let container = LLMKitFactory.makeContainer(
            catalog: catalog,
            backends: [foundationModelsBackend]
        )

        return LLMKitExampleConfiguration(
            container: container,
            catalog: catalog,
            backends: [foundationModelsBackend],
            downloadableModels: downloadableModels
        )
    }

    public static func localQwenSmokeTest() -> LLMKitExampleConfiguration {
        appleIntelligenceOnly(downloadableModels: [
            LLMKitExampleModels.qwen25HalfBInstructMLX4Bit
        ])
    }

    func backend(for kind: BackendKind) -> (any ModelBackend)? {
        backends.first { $0.backendKind == kind }
    }
}
