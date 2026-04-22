import LLMBackendFoundationModels
import LLMCore
import Testing

@Test func foundationModelsBackendReportsKind() {
    #expect(FoundationModelsBackend().backendKind == .foundationModels)
}
