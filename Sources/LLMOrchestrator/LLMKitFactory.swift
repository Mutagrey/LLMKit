import Foundation
import LLMCore
import LLMModelLifecycle
import LLMProtocols
import LLMSessions

public enum LLMKitFactory {
    public static func makeContainer(
        catalog: any ModelCatalogProviding,
        backends: [any ModelBackend],
        lifecycle: (any ModelLifecycleService)? = nil
    ) -> LLMKitContainer {
        let registry = BackendRegistry(backends: backends)
        let router = ModelRouter(catalog: catalog)
        let generation = DefaultLanguageGenerationService(router: router, registry: registry)
        let chat = DefaultChatService(router: router, registry: registry)
        let structured = DefaultStructuredGenerationService(generation: generation)
        let lifecycle = lifecycle ?? ModelInstallCoordinator(
            artifactRootDirectory: defaultArtifactRootDirectory()
        )
        let sessions = SessionCoordinator()
        return LLMKitContainer(
            generation: generation,
            chat: chat,
            structured: structured,
            lifecycle: lifecycle,
            sessions: sessions
        )
    }

    private static func defaultArtifactRootDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("LLMKit", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }
}
