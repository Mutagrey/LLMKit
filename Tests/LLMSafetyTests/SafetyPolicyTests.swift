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

private struct StaticOutputGuard: OutputGuarding {
    let decision: SafetyDecision

    func evaluate(_ request: SafetyOutputRequest) async -> SafetyDecision {
        decision
    }
}

@Test func piiRedactorMasksEmailAddresses() {
    let redacted = PIIRedactor().redact("Contact me at user@example.com")

    #expect(redacted == "Contact me at [redacted-email]")
}

@Test func piiRedactorLeavesTextWithoutEmailUnchanged() {
    let text = "No email address here"

    #expect(PIIRedactor().redact(text) == text)
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

@Test func allowAllPolicyAllowsOutput() async {
    let decision = await AllowAllSafetyPolicy().evaluateOutput(SafetyOutputRequest(text: "hello", modelID: "model"))

    #expect(decision == .allow)
}

@Test func compositeInputPolicyAllowsWhenAllGuardsAllow() async {
    let evaluator = CompositeInputPolicyEvaluator(guards: [
        StaticInputGuard(decision: .allow),
        StaticInputGuard(decision: .allow)
    ])

    let decision = await evaluator.evaluate(SafetyInputRequest(text: "hello"))

    #expect(decision == .allow)
}

@Test func compositeOutputPolicyStopsAtFirstNonAllowDecision() async {
    let evaluator = CompositeOutputPolicyEvaluator(guards: [
        StaticOutputGuard(decision: .allow),
        StaticOutputGuard(decision: SafetyDecision(action: .modify(reason: "redact"), redactedText: "safe")),
        StaticOutputGuard(decision: SafetyDecision(action: .deny(reason: "late")))
    ])

    let decision = await evaluator.evaluate(SafetyOutputRequest(text: "hello"))

    #expect(decision.action == .modify(reason: "redact"))
    #expect(decision.redactedText == "safe")
}
