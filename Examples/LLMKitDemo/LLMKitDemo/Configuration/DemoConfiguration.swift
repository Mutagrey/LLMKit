import Foundation
import LLMCore
import LLMModelLifecycle
import LLMProtocols

enum DemoConfiguration {
    static func make() -> DemoRuntimeConfiguration {
        let localFallback = fallbackManifest()
        if let remoteSource = remoteCatalogSourceFromEnvironment() {
            return .dynamicRemoteManifest(
                remoteSource: remoteSource,
                fallbackManifest: localFallback,
                includeAppleIntelligence: true,
                runtimeAvailable: true,
                lifecycle: makeLifecycle()
            )
        }

        return .liveHuggingFaceCatalog(
            fallbackManifest: localFallback,
            includeAppleIntelligence: true,
            runtimeAvailable: true,
            lifecycle: makeLifecycle()
        )
    }

    static func preview() -> DemoRuntimeConfiguration {
        DemoRuntimeConfiguration.liveHuggingFaceCatalog(
            fallbackManifest: fallbackManifest(),
            includeAppleIntelligence: true,
            runtimeAvailable: false,
            lifecycle: makeLifecycle(),
            fetchCatalogData: { _ in throw URLError(.notConnectedToInternet) }
        )
    }

    private static func fallbackManifest() -> ModelManifest {
        ModelManifest(
            id: "llmkit.demo.fallback-catalog",
            models: CuratedModelManifests.localIPhoneTextModels.models
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
