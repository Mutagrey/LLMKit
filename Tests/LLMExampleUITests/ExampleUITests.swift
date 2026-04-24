import LLMCore
import LLMExampleUI
import Testing

@Test func appleIntelligenceExampleDescriptorIsSystemManagedChatModel() {
    let descriptor = LLMKitExampleModels.appleIntelligence

    #expect(descriptor.id.rawValue == "apple.system.foundation.default")
    #expect(descriptor.displayName == "Apple Intelligence")
    #expect(descriptor.capabilities.contains(.chat))
    #expect(descriptor.tags.contains("system-managed"))
}

@Test func qwenSmokeTestDescriptorIsDownloadableMLXModel() {
    let descriptor = LLMKitExampleModels.qwen25HalfBInstructMLX4Bit

    #expect(descriptor.backend == .mlx)
    #expect(descriptor.family == .qwen)
    #expect(descriptor.capabilities.contains(.chat))
    #expect(descriptor.source?.provider == .huggingFace)
    #expect(descriptor.source?.repository == "mlx-community/Qwen2.5-0.5B-Instruct-4bit")
    #expect(descriptor.source?.artifacts.contains { $0.relativePath == "model.safetensors" } == true)
    #expect(descriptor.license?.spdxIdentifier == "Apache-2.0")
    #expect(descriptor.tags.contains("smoke-test"))
}

@Test func curatedLocalCatalogExposesMultipleIPhoneSizedModels() {
    let models = LLMKitExampleModels.localIPhoneTextModels

    #expect(models.count >= 5)
    #expect(models.contains { $0.id.rawValue == "mlx-community.Qwen3-0.6B-4bit" })
    #expect(models.contains { $0.id.rawValue == "mlx-community.Qwen3-1.7B-4bit" })
    #expect(models.contains { $0.id.rawValue == "mlx-community.gemma-3-1b-it-4bit" })
}

@Test func localIPhoneCatalogConfiguresDownloadableModelsFromManifest() async throws {
    let configuration = LLMKitExampleConfiguration.localIPhoneCatalog()
    let models = try await configuration.catalog.availableModels()

    #expect(configuration.downloadableModels.count == LLMKitExampleModels.localIPhoneTextModels.count)
    #expect(models.contains { $0.id == LLMKitExampleModels.appleIntelligence.id })
    #expect(models.contains { $0.id == LLMKitExampleModels.qwen34BMLX4Bit.id })
}

@MainActor
@Test func exampleViewModelDefaultsPreferLocalAppleIntelligenceSmokeTest() {
    let viewModel = LLMKitExampleViewModel(configuration: .appleIntelligenceOnly())

    #expect(viewModel.executionMode == .preferOffline)
    #expect(viewModel.privacyMode == .localOnly)
    #expect(viewModel.qualityTier == .balanced)
    #expect(viewModel.maxOutputTokens == 512)
}
