import LLMCore

public struct RequestNormalizer: Sendable {
    public init() {}

    public func normalize(_ request: GenerationRequest) -> GenerationRequest {
        request
    }
}

public struct ResponseAssembler: Sendable {
    public init() {}
}

public struct ExecutionContextBuilder: Sendable {
    public init() {}
}
