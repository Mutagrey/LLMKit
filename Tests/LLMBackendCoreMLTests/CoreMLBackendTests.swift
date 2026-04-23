import LLMBackendCoreML
import LLMCore
import LLMProtocols
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

@Test func coreMLBackendRejectsWrongBackendDescriptor() async throws {
    let descriptor = ModelDescriptor(id: "remote", displayName: "Remote", family: .custom("test"), backend: .remote, capabilities: [.completion], isRemote: true)
    let backend = CoreMLBackend()

    let availability = await backend.availability(for: descriptor)

    #expect(availability.status == .unsupported)
    do {
        _ = try await backend.loadModel(descriptor)
        Issue.record("Expected Core ML backend to reject non-Core ML descriptor.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}

@Test func coreMLSkeletonStreamsUnavailableUntilImplemented() async throws {
    let descriptor = ModelDescriptor(id: "coreml", displayName: "Core ML", family: .custom("test"), backend: .coreML, capabilities: [.completion])
    let backend = CoreMLBackend()

    do {
        for try await _ in backend.generate(BackendGenerationRequest(request: GenerationRequest(prompt: "hello"), model: descriptor)) {}
        Issue.record("Expected Core ML generation skeleton to be unavailable.")
    } catch {
        #expect(error as? LLMError == .unavailable)
    }
}
