import Foundation
import LLMBackendFoundationModels
import LLMBackendLlamaCpp
import LLMBackendMLX
import LLMCore
import LLMModelLifecycle
import LLMPrompting
import LLMOrchestrator
import LLMProtocols
import LLMSessions
import LLMStorage

struct DemoRuntimeConfiguration: Sendable {
    let container: LLMKitContainer
    let catalog: any ModelCatalogProviding
    let catalogStatusProvider: (any ModelCatalogStatusProviding)?
    let backends: [any ModelBackend]
    let downloadableModels: [ModelDescriptor]
    let sessionStore: (any SessionStore)?

    init(
        container: LLMKitContainer,
        catalog: any ModelCatalogProviding,
        catalogStatusProvider: (any ModelCatalogStatusProviding)? = nil,
        backends: [any ModelBackend],
        downloadableModels: [ModelDescriptor] = [],
        sessionStore: (any SessionStore)? = nil
    ) {
        self.container = container
        self.catalog = catalog
        self.catalogStatusProvider = catalogStatusProvider
        self.backends = backends
        self.downloadableModels = downloadableModels
        self.sessionStore = sessionStore
    }

    func makeAutomationCoordinator() -> AutomatedConversationCoordinator {
        AutomatedConversationCoordinator(
            sessionService: container.sessions,
            chatService: container.chat,
            promptRenderer: AutomatedConversationPromptRenderer()
        )
    }

    static func dynamicRemoteManifest(
        remoteSource: RemoteModelCatalogSource,
        fallbackManifest: ModelManifest = CuratedModelManifests.localIPhoneTextModels,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true,
        additionalBackends: [any ModelBackend] = [],
        lifecycle: (any ModelLifecycleService)? = nil,
        sessionStore: (any SessionStore)? = defaultSessionStore(),
        fetchManifestData: @escaping @Sendable (URL) async throws -> Data = DynamicModelCatalog.defaultFetchManifestData
    ) -> DemoRuntimeConfiguration {
        let fallbackCatalog = DefaultModelCatalog(manifest: fallbackManifest)
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

        let resolvedBackends = makeBackends(
            includeAppleIntelligence: includeAppleIntelligence,
            runtimeAvailable: runtimeAvailable,
            additionalBackends: additionalBackends
        )

        let container = LLMKitFactory.makeContainer(
            catalog: catalog,
            backends: resolvedBackends,
            lifecycle: lifecycle,
            sessionStore: sessionStore
        )

        return DemoRuntimeConfiguration(
            container: container,
            catalog: catalog,
            catalogStatusProvider: remoteCatalog,
            backends: resolvedBackends,
            downloadableModels: fallbackManifest.models.filter { $0.tags.contains("downloadable") },
            sessionStore: sessionStore
        )
    }

    static func liveHuggingFaceCatalog(
        fallbackManifest: ModelManifest = CuratedModelManifests.localIPhoneTextModels,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true,
        additionalBackends: [any ModelBackend] = [],
        lifecycle: (any ModelLifecycleService)? = nil,
        sessionStore: (any SessionStore)? = defaultSessionStore(),
        fetchCatalogData: @escaping @Sendable (URL) async throws -> Data = HuggingFaceFeaturedModelCatalog.defaultFetchData
    ) -> DemoRuntimeConfiguration {
        let fallbackCatalogManifest = includeAppleIntelligence
            ? CuratedModelManifests.merged(
                id: "llmkit.example.live-fallback-catalog",
                manifests: [CuratedModelManifests.appleFoundation, fallbackManifest]
            )
            : fallbackManifest
        let fallbackCatalog = DefaultModelCatalog(manifest: fallbackCatalogManifest)
        let liveCatalog = HuggingFaceFeaturedModelCatalog(
            fallbackCatalog: fallbackCatalog,
            fetchData: fetchCatalogData
        )

        let resolvedBackends = makeBackends(
            includeAppleIntelligence: includeAppleIntelligence,
            runtimeAvailable: runtimeAvailable,
            additionalBackends: additionalBackends
        )

        let container = LLMKitFactory.makeContainer(
            catalog: liveCatalog,
            backends: resolvedBackends,
            lifecycle: lifecycle,
            sessionStore: sessionStore
        )

        return DemoRuntimeConfiguration(
            container: container,
            catalog: liveCatalog,
            catalogStatusProvider: liveCatalog,
            backends: resolvedBackends,
            downloadableModels: fallbackManifest.models.filter { $0.tags.contains("downloadable") },
            sessionStore: sessionStore
        )
    }

    func backend(for kind: BackendKind) -> (any ModelBackend)? {
        backends.first { $0.backendKind == kind }
    }

    private static func makeBackends(
        includeAppleIntelligence: Bool,
        runtimeAvailable: Bool,
        additionalBackends: [any ModelBackend]
    ) -> [any ModelBackend] {
        var backends: [any ModelBackend] = []
        if includeAppleIntelligence {
            backends.append(FoundationModelsBackend())
        }
        backends.append(MLXBackend(runtimeAvailable: runtimeAvailable))
        backends.append(LlamaCppBackend(runtimeAvailable: runtimeAvailable))
        backends.append(contentsOf: additionalBackends)
        return backends
    }

    static func defaultSessionStore() -> (any SessionStore)? {
        guard let rootDirectory = StoragePaths.defaultRootDirectory() else {
            return nil
        }
        return SessionFileStore(paths: StoragePaths(rootDirectory: rootDirectory))
    }
}
