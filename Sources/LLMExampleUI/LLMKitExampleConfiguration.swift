import Foundation
import LLMBackendFoundationModels
import LLMBackendMLX
import LLMCore
import LLMModelLifecycle
import LLMPrompting
import LLMOrchestrator
import LLMProtocols
import LLMSessions
import LLMStorage

public struct LLMKitExampleConfiguration: Sendable {
    public let container: LLMKitContainer
    public let catalog: any ModelCatalogProviding
    public let catalogStatusProvider: (any ModelCatalogStatusProviding)?
    public let backends: [any ModelBackend]
    public let downloadableModels: [ModelDescriptor]
    public let sessionStore: (any SessionStore)?

    public init(
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

    public func makeAutomationCoordinator() -> AutomatedConversationCoordinator {
        AutomatedConversationCoordinator(
            sessionService: container.sessions,
            chatService: container.chat,
            promptRenderer: AutomatedConversationPromptRenderer()
        )
    }

    public static func appleIntelligenceOnly(
        downloadableModels: [ModelDescriptor] = [],
        sessionStore: (any SessionStore)? = defaultSessionStore()
    ) -> LLMKitExampleConfiguration {
        configuration(
            localManifest: ModelManifest(id: "llmkit.example.apple-only", models: downloadableModels),
            includeAppleIntelligence: true,
            runtimeAvailable: !downloadableModels.isEmpty,
            sessionStore: sessionStore
        )
    }

    public static func localIPhoneCatalog(
        sessionStore: (any SessionStore)? = defaultSessionStore()
    ) -> LLMKitExampleConfiguration {
        configuration(
            localManifest: CuratedModelManifests.localIPhoneTextModels,
            includeAppleIntelligence: true,
            runtimeAvailable: true,
            sessionStore: sessionStore
        )
    }

    public static func localQwenSmokeTest(
        sessionStore: (any SessionStore)? = defaultSessionStore()
    ) -> LLMKitExampleConfiguration {
        configuration(
            localManifest: ModelManifest(
                id: "llmkit.example.qwen-smoke-test",
                models: [CuratedModelManifests.qwen25HalfBInstructMLX4Bit]
            ),
            includeAppleIntelligence: true,
            runtimeAvailable: true,
            sessionStore: sessionStore
        )
    }

    public static func manifest(
        _ manifest: ModelManifest,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true,
        sessionStore: (any SessionStore)? = defaultSessionStore()
    ) -> LLMKitExampleConfiguration {
        configuration(
            localManifest: manifest,
            includeAppleIntelligence: includeAppleIntelligence,
            runtimeAvailable: runtimeAvailable,
            sessionStore: sessionStore
        )
    }

    public static func remoteManifest(
        _ manifestURL: URL,
        expectedSignature: ModelManifestSignature? = nil,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true,
        sessionStore: (any SessionStore)? = defaultSessionStore()
    ) async throws -> LLMKitExampleConfiguration {
        let manifest = try await ManifestLoader().load(
            remoteManifestAt: manifestURL,
            expectedSignature: expectedSignature
        )
        return configuration(
            localManifest: manifest,
            includeAppleIntelligence: includeAppleIntelligence,
            runtimeAvailable: runtimeAvailable,
            sessionStore: sessionStore
        )
    }

    public static func dynamicRemoteManifest(
        remoteSource: RemoteModelCatalogSource,
        fallbackManifest: ModelManifest = CuratedModelManifests.localIPhoneTextModels,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true,
        additionalBackends: [any ModelBackend] = [],
        lifecycle: (any ModelLifecycleService)? = nil,
        sessionStore: (any SessionStore)? = defaultSessionStore(),
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
            lifecycle: lifecycle,
            sessionStore: sessionStore
        )

        return LLMKitExampleConfiguration(
            container: container,
            catalog: catalog,
            catalogStatusProvider: remoteCatalog,
            backends: resolvedBackends,
            downloadableModels: fallbackManifest.models.filter { $0.tags.contains("downloadable") },
            sessionStore: sessionStore
        )
    }

    public static func liveHuggingFaceCatalog(
        fallbackManifest: ModelManifest = CuratedModelManifests.localIPhoneTextModels,
        includeAppleIntelligence: Bool = true,
        runtimeAvailable: Bool = true,
        additionalBackends: [any ModelBackend] = [],
        lifecycle: (any ModelLifecycleService)? = nil,
        sessionStore: (any SessionStore)? = defaultSessionStore(),
        fetchCatalogData: @escaping @Sendable (URL) async throws -> Data = HuggingFaceFeaturedModelCatalog.defaultFetchData
    ) -> LLMKitExampleConfiguration {
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

        var resolvedBackends: [any ModelBackend] = []
        if includeAppleIntelligence {
            resolvedBackends.append(FoundationModelsBackend())
        }
        resolvedBackends.append(MLXBackend(runtimeAvailable: runtimeAvailable))
        resolvedBackends.append(contentsOf: additionalBackends)

        let container = LLMKitFactory.makeContainer(
            catalog: liveCatalog,
            backends: resolvedBackends,
            lifecycle: lifecycle,
            sessionStore: sessionStore
        )

        return LLMKitExampleConfiguration(
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

    private static func configuration(
        localManifest: ModelManifest,
        includeAppleIntelligence: Bool,
        runtimeAvailable: Bool,
        sessionStore: (any SessionStore)? = defaultSessionStore()
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
            backends: resolvedBackends,
            sessionStore: sessionStore
        )

        return LLMKitExampleConfiguration(
            container: container,
            catalog: catalog,
            catalogStatusProvider: nil,
            backends: resolvedBackends,
            downloadableModels: downloadableModels,
            sessionStore: sessionStore
        )
    }

    public static func defaultSessionStore() -> (any SessionStore)? {
        guard let rootDirectory = StoragePaths.defaultRootDirectory() else {
            return nil
        }
        return SessionFileStore(paths: StoragePaths(rootDirectory: rootDirectory))
    }
}
