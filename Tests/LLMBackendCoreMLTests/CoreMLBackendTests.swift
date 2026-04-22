import LLMBackendCoreML
import LLMCore
import Testing

@Test func coreMLCompatibilityCheckerMatchesBackendKind() {
    let descriptor = ModelDescriptor(id: "coreml", displayName: "Core ML", family: .custom("test"), backend: .coreML, capabilities: [])

    #expect(CoreMLModelCompatibilityChecker().isCompatible(descriptor))
}

@Test func coreMLBackendLoadsCompatibleModelHandle() async throws {
    let descriptor = ModelDescriptor(id: "coreml", displayName: "Core ML", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let backend = CoreMLBackend()

    let handle = try await backend.loadModel(descriptor)

    #expect(await backend.availability(for: descriptor).status == .available)
    #expect(handle.id == descriptor.id)
}
