import LLMCore

public struct BackendGenerationRequest: Sendable {
    public let request: GenerationRequest
    public let model: ModelDescriptor
    public let traceID: TraceID?

    public init(request: GenerationRequest, model: ModelDescriptor, traceID: TraceID? = nil) {
        self.request = request
        self.model = model
        self.traceID = traceID
    }
}

public struct BackendChatRequest: Sendable {
    public let request: ChatRequest
    public let model: ModelDescriptor
    public let traceID: TraceID?

    public init(request: ChatRequest, model: ModelDescriptor, traceID: TraceID? = nil) {
        self.request = request
        self.model = model
        self.traceID = traceID
    }
}

public typealias BackendGenerationEvent = GenerationEvent
public typealias BackendChatEvent = ChatEvent
