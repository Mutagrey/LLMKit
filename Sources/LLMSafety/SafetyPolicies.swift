import LLMCore
import LLMProtocols

public struct AllowAllSafetyPolicy: SafetyPolicyEvaluating {
    public init() {}

    public func evaluateInput(_ request: SafetyInputRequest) async -> SafetyDecision {
        .allow
    }

    public func evaluateOutput(_ request: SafetyOutputRequest) async -> SafetyDecision {
        .allow
    }
}

public struct CompositeInputPolicyEvaluator: InputGuarding {
    private let guards: [any InputGuarding]

    public init(guards: [any InputGuarding]) {
        self.guards = guards
    }

    public func evaluate(_ request: SafetyInputRequest) async -> SafetyDecision {
        for guardPolicy in guards {
            let decision = await guardPolicy.evaluate(request)
            if decision.action != .allow {
                return decision
            }
        }
        return .allow
    }
}

public struct CompositeOutputPolicyEvaluator: OutputGuarding {
    private let guards: [any OutputGuarding]

    public init(guards: [any OutputGuarding]) {
        self.guards = guards
    }

    public func evaluate(_ request: SafetyOutputRequest) async -> SafetyDecision {
        for guardPolicy in guards {
            let decision = await guardPolicy.evaluate(request)
            if decision.action != .allow {
                return decision
            }
        }
        return .allow
    }
}

public struct PIIRedactor: Sendable {
    public init() {}

    public func redact(_ text: String) -> String {
        text.replacingOccurrences(of: #"[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}"#, with: "[redacted-email]", options: .regularExpression)
    }
}
