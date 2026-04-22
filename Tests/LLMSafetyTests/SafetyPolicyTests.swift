import LLMCore
import LLMSafety
import Testing

@Test func piiRedactorMasksEmailAddresses() {
    let redacted = PIIRedactor().redact("Contact me at user@example.com")

    #expect(redacted == "Contact me at [redacted-email]")
}

@Test func allowAllPolicyAllowsInput() async {
    let decision = await AllowAllSafetyPolicy().evaluateInput(SafetyInputRequest(text: "hello"))

    #expect(decision == .allow)
}
