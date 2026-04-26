import Foundation
import LLMCore
import LLMExampleUI
import LLMModelLifecycle
import LLMProtocols

enum DemoConfiguration {
    static func make() -> LLMKitExampleConfiguration {
        let fallbackManifest = ModelManifest(
            id: "llmkit.demo.fallback-catalog",
            models: LLMKitExampleModels.localIPhoneTextModels
        )
        if let remoteSource = remoteCatalogSourceFromEnvironment() {
            return .dynamicRemoteManifest(
                remoteSource: remoteSource,
                fallbackManifest: fallbackManifest,
                includeAppleIntelligence: true,
                runtimeAvailable: true,
                lifecycle: makeLifecycle()
            )
        }

        return .liveHuggingFaceCatalog(
            fallbackManifest: fallbackManifest,
            includeAppleIntelligence: true,
            runtimeAvailable: true,
            lifecycle: makeLifecycle()
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
