import LLMBackendCoreML
import LLMCore
import Testing

@Test func coreMLCompatibilityCheckerMatchesBackendKind() {
    let descriptor = ModelDescriptor(id: "coreml", displayName: "Core ML", family: .custom("test"), backend: .coreML, capabilities: [])

    #expect(CoreMLModelCompatibilityChecker().isCompatible(descriptor))
}
