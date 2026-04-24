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
            backends: resolvedBackends,
            downloadableModels: downloadableModels
        )
    }
}
