import Foundation
import LLMBackendFoundationModels
import LLMBackendMLX
import LLMCore
import LLMModelLifecycle
import LLMOrchestrator
import LLMProtocols

public struct LLMKitExampleConfiguration: Sendable {
    public let container: LLMKitContainer
    public let catalog: any ModelCatalogProviding
    public let catalogStatusProvider: (any ModelCatalogStatusProviding)?
    public let backends: [any ModelBackend]
    public let downloadableModels: [ModelDescriptor]

    public init(
        container: LLMKitContainer,
        catalog: any ModelCatalogProviding,
        catalogStatusProvider: (any ModelCatalogStatusProviding)? = nil,
        backends: [any ModelBackend],
        downloadableModels: [ModelDescriptor] = []
    ) {
        self.container = container
        self.catalog = catalog
        self.catalogStatusProvider = catalogStatusProvider
        self.backends = backends
        self.downloadableModels = downloadableModels
    }

    public static func appleIntelligenceOnly(
        downloadableModels: [ModelDescriptor] = []
    ) -> LLMKitExampleConfiguration {
        configuration(
            localManifest: ModelManifest(id: "llmkit.example.apple-only", models: downloadableModels),
            includeAppleIntelligence: true,
            runtimeAvailable: !downloadableModels.isEmpty
        )
    }

    public static func localIPhoneCatalog() -> LLMKitExampleConfiguration {
        configuration(
            localManifest: CuratedModelManifests.localIPhoneTextModels,
            includeAppleIntelligence: true,
            runtimeAvailable: true
        )
    }

    public static func localQwenSmokeTest() -> LLMKitExampleConfiguration {
        configuration(
            localManifest: ModelManifest(
                id: "llmkit.example.qwen-smoke-test",
                models: [CuratedModelManifests.qwen25HalfBInstructMLX4Bit]
            ),
            includeAppleIntelligence: true,
            runtimeAvailable: true
        )
    }

    public static func manifest(
        _ manifest: ModelManifest,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true
    ) -> LLMKitExampleConfiguration {
        configuration(
            localManifest: manifest,
            includeAppleIntelligence: includeAppleIntelligence,
            runtimeAvailable: runtimeAvailable
        )
    }

    public static func remoteManifest(
        _ manifestURL: URL,
        expectedSignature: ModelManifestSignature? = nil,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true
    ) async throws -> LLMKitExampleConfiguration {
        let manifest = try await ManifestLoader().load(
            remoteManifestAt: manifestURL,
            expectedSignature: expectedSignature
        )
        return configuration(
            localManifest: manifest,
            includeAppleIntelligence: includeAppleIntelligence,
            runtimeAvailable: runtimeAvailable
        )
    }

    public static func dynamicRemoteManifest(
        remoteSource: RemoteModelCatalogSource,
        fallbackManifest: ModelManifest = CuratedModelManifests.localIPhoneTextModels,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true,
        additionalBackends: [any ModelBackend] = [],
        lifecycle: (any ModelLifecycleService)? = nil,
        fetchManifestData: @escaping @Sendable (URL) async throws -> Data = DynamicModelCatalog.defaultFetchManifestData
    ) -> LLMKitExampleConfiguration {
        let fallbackCatalogManifest = includeAppleIntelligence
            ? CuratedModelManifests.merged(
                id: "llmkit.example.dynamic-fallback-catalog",
                manifests: [CuratedModelManifests.appleFoundation, fallbackManifest]
            )
            : fallbackManifest
        let fallbackCatalog = DefaultModelCatalog(manifest: fallbackCatalogManifest)
        let remoteCatalog = DynamicModelCatalog(
            remoteSource: remoteSource,
            fallbackCatalog: fallbackCatalog,
            fetchManifestData: fetchManifestData
        )
        let catalog: any ModelCatalogProviding
        if includeAppleIntelligence {
            catalog = CompositeModelCatalog(catalogs: [
                DefaultModelCatalog(manifest: CuratedModelManifests.appleFoundation),
                remoteCatalog
            ])
        } else {
            catalog = remoteCatalog
        }

        var resolvedBackends: [any ModelBackend] = []
        if includeAppleIntelligence {
            resolvedBackends.append(FoundationModelsBackend())
        }
        resolvedBackends.append(MLXBackend(runtimeAvailable: runtimeAvailable))
        resolvedBackends.append(contentsOf: additionalBackends)

        let container = LLMKitFactory.makeContainer(
            catalog: catalog,
            backends: resolvedBackends,
            lifecycle: lifecycle
        )

        return LLMKitExampleConfiguration(
            container: container,
            catalog: catalog,
            catalogStatusProvider: remoteCatalog,
            backends: resolvedBackends,
            downloadableModels: fallbackManifest.models.filter { $0.tags.contains("downloadable") }
        )
    }

    func backend(for kind: BackendKind) -> (any ModelBackend)? {
        backends.first { $0.backendKind == kind }
    }

    private static func configuration(
        localManifest: ModelManifest,
        includeAppleIntelligence: Bool,
        runtimeAvailable: Bool
    ) -> LLMKitExampleConfiguration {
        let catalogManifest = includeAppleIntelligence
            ? CuratedModelManifests.merged(
                id: "llmkit.example.composed-catalog",
                manifests: [CuratedModelManifests.appleFoundation, localManifest]
            )
            : localManifest
        let downloadableModels = localManifest.models.filter { $0.tags.contains("downloadable") }
        let catalog = DefaultModelCatalog(manifest: catalogManifest)
        var resolvedBackends: [any ModelBackend] = []

        if includeAppleIntelligence {
            resolvedBackends.append(FoundationModelsBackend())
        }
        if localManifest.models.contains(where: { $0.backend == .mlx }) {
            resolvedBackends.append(MLXBackend(runtimeAvailable: runtimeAvailable))
        }

        let container = LLMKitFactory.makeContainer(
            catalog: catalog,
            backends: resolvedBackends
        )

        return LLMKitExampleConfiguration(
            container: container,
            catalog: catalog,
            catalogStatusProvider: nil,
            backends: resolvedBackends,
            downloadableModels: downloadableModels
        )
    }
}
