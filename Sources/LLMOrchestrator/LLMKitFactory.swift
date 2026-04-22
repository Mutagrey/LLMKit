import LLMCore
import LLMModelLifecycle
import LLMProtocols
import LLMSessions

public enum LLMKitFactory {
    public static func makeContainer(catalog: any ModelCatalogProviding, backends: [any ModelBackend]) -> LLMKitContainer {
        let registry = BackendRegistry(backends: backends)
        let router = ModelRouter(catalog: catalog)
        let generation = DefaultLanguageGenerationService(router: router, registry: registry)
        let chat = DefaultChatService(router: router, registry: registry)
        let structured = DefaultStructuredGenerationService(generation: generation)
        let lifecycle = ModelInstallCoordinator()
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
