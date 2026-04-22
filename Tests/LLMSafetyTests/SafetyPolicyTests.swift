import LLMCore
import LLMProtocols
import LLMSafety
import Testing

private struct StaticInputGuard: InputGuarding {
    let decision: SafetyDecision

    func evaluate(_ request: SafetyInputRequest) async -> SafetyDecision {
        decision
    }
}

@Test func piiRedactorMasksEmailAddresses() {
    let redacted = PIIRedactor().redact("Contact me at user@example.com")

    #expect(redacted == "Contact me at [redacted-email]")
}

@Test func allowAllPolicyAllowsInput() async {
    let decision = await AllowAllSafetyPolicy().evaluateInput(SafetyInputRequest(text: "hello"))

    #expect(decision == .allow)
}

@Test func compositeInputPolicyStopsAtFirstNonAllowDecision() async {
    let evaluator = CompositeInputPolicyEvaluator(guards: [
        StaticInputGuard(decision: .allow),
        StaticInputGuard(decision: SafetyDecision(action: .deny(reason: "blocked"))),
        StaticInputGuard(decision: SafetyDecision(action: .modify(reason: "late"), redactedText: "late"))
    ])

    let decision = await evaluator.evaluate(SafetyInputRequest(text: "hello"))

    #expect(decision.action == .deny(reason: "blocked"))
    #expect(decision.redactedText == nil)
}
