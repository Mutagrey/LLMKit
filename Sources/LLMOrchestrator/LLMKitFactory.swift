import LLMCore
import LLMModelLifecycle
import LLMProtocols
import LLMSessions

public enum LLMKitFactory {
    public static func makeContainer(
        catalog: any ModelCatalogProviding,
        backends: [any ModelBackend],
        lifecycle: (any ModelLifecycleService)? = nil,
        tools: (any ToolService)? = nil
    ) -> LLMKitContainer {
        let registry = BackendRegistry(backends: backends)
        let router = ModelRouter(catalog: catalog)
        let generation = DefaultLanguageGenerationService(router: router, registry: registry)
        let chat = DefaultChatService(router: router, registry: registry, tools: tools)
        let structured = DefaultStructuredGenerationService(generation: generation)
        let lifecycle = lifecycle ?? ModelInstallCoordinator(
            artifactRootDirectory: ModelArtifactLocationResolver.defaultRootDirectory()
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
}
