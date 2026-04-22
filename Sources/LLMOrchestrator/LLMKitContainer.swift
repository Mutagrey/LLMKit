import LLMProtocols

public struct LLMKitContainer: Sendable {
    public let generation: any LanguageGenerationService
    public let chat: any ChatService
    public let structured: any StructuredGenerationService
    public let embeddings: (any EmbeddingService)?
    public let lifecycle: any ModelLifecycleService
    public let sessions: any SessionService

    public init(
        generation: any LanguageGenerationService,
        chat: any ChatService,
        structured: any StructuredGenerationService,
        embeddings: (any EmbeddingService)? = nil,
        lifecycle: any ModelLifecycleService,
        sessions: any SessionService
    ) {
        self.generation = generation
        self.chat = chat
        self.structured = structured
        self.embeddings = embeddings
        self.lifecycle = lifecycle
        self.sessions = sessions
    }
}
