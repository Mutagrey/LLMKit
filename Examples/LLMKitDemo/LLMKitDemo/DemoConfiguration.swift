import Foundation
import LLMBackendFoundationModels
import LLMBackendMLX
import LLMCore
import LLMExampleUI
import LLMModelLifecycle
import LLMOrchestrator
import LLMProtocols

enum DemoConfiguration {
    static func make() -> LLMKitExampleConfiguration {
        let fallbackManifest = ModelManifest(
            id: "llmkit.demo.fallback-catalog",
            models: [demoEchoModel] + LLMKitExampleModels.localIPhoneTextModels
        )
        if let remoteSource = remoteCatalogSourceFromEnvironment() {
            return .dynamicRemoteManifest(
                remoteSource: remoteSource,
                fallbackManifest: fallbackManifest,
                includeAppleIntelligence: true,
                runtimeAvailable: true,
                additionalBackends: [DemoEchoBackend()],
                lifecycle: makeLifecycle()
            )
        }

        let downloadableModels = fallbackManifest.models.filter { $0.tags.contains("downloadable") }
        let models = [LLMKitExampleModels.appleIntelligence] + fallbackManifest.models
        let catalog = DefaultModelCatalog(models: models)
        let backends: [any ModelBackend] = [
            FoundationModelsBackend(),
            MLXBackend(runtimeAvailable: true),
            DemoEchoBackend()
        ]
        let container = LLMKitFactory.makeContainer(
            catalog: catalog,
            backends: backends,
            lifecycle: makeLifecycle()
        )

        return LLMKitExampleConfiguration(
            container: container,
            catalog: catalog,
            backends: backends,
            downloadableModels: downloadableModels
        )
    }

    private static func makeLifecycle() -> any ModelLifecycleService {
        let modelRootDirectory = ModelArtifactLocationResolver.defaultRootDirectory()
        let manifestDirectory = modelRootDirectory?
            .deletingLastPathComponent()
            .appendingPathComponent("Manifests", isDirectory: true)
        let recordStore = manifestDirectory.map { directory in
            InstalledModelRecordStore(manifestStore: DemoManifestFileStore(directory: directory))
        }

        return ModelInstallCoordinator(
            recordStore: recordStore,
            artifactRootDirectory: modelRootDirectory
        )
    }

    private static func remoteCatalogSourceFromEnvironment() -> RemoteModelCatalogSource? {
        let environment = ProcessInfo.processInfo.environment
        guard let urlValue = environment["LLMKIT_REMOTE_CATALOG_URL"],
              let url = URL(string: urlValue),
              let signature = environment["LLMKIT_REMOTE_CATALOG_SIGNATURE"],
              let publicKey = environment["LLMKIT_REMOTE_CATALOG_PUBLIC_KEY"] else {
            return nil
        }

        return RemoteModelCatalogSource(
            url: url,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: signature,
                publicKeyValue: publicKey
            )
        )
    }

    private static let demoEchoModel = ModelDescriptor(
        id: "demo.echo",
        displayName: "Demo Echo",
        family: .custom("demo"),
        backend: .custom("demo"),
        capabilities: [
            .chat,
            .completion,
            .streaming,
            .offline,
            .lowLatency
        ],
        contextWindowTokens: 4096,
        supportsStreaming: true,
        tags: [
            "demo",
            "simulator-safe"
        ]
    )
}

private actor DemoManifestFileStore: ManifestStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func loadManifest(named name: String) async throws -> Data? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    func saveManifest(_ data: Data, named name: String) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(name), options: [.atomic])
    }
}
