import LLMCore

public protocol SafetyPolicyEvaluating: Sendable {
    func evaluateInput(_ request: SafetyInputRequest) async -> SafetyDecision
    func evaluateOutput(_ request: SafetyOutputRequest) async -> SafetyDecision
}

public protocol InputGuarding: Sendable {
    func evaluate(_ request: SafetyInputRequest) async -> SafetyDecision
}

public protocol OutputGuarding: Sendable {
    func evaluate(_ request: SafetyOutputRequest) async -> SafetyDecision
}

public protocol ToolPermissionEvaluating: Sendable {
    func evaluate(_ invocation: ToolInvocation, definition: ToolDefinition) async -> SafetyDecision
}
