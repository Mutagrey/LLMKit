import Foundation

public enum GenerationEvent: Equatable, Sendable {
    case started(ModelDescriptor)
    case delta(String)
    case completed(GenerationResult)
    case failed(LLMError)
}

public enum ChatEvent: Equatable, Sendable {
    case started(ModelDescriptor)
    case delta(String)
    case toolCallRequested(ToolInvocation)
    case toolCallCompleted(ToolResult)
    case completed(ChatResult)
    case failed(LLMError)
}

public enum ToolEvent: Equatable, Sendable {
    case requested(ToolInvocation)
    case completed(ToolResult)
    case failed(ToolInvocation, LLMError)
}
