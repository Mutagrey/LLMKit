import CryptoKit
import Foundation
import LLMCore
import LLMExampleUI
import LLMModelLifecycle
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
@Test func dynamicRemoteManifestConfigurationSurfacesFetchedDownloadableModels() async throws {
    let remoteModel = ModelDescriptor(
        id: "remote.qwen",
        displayName: "Remote Qwen",
        family: .qwen,
        backend: .mlx,
        capabilities: [.chat, .completion, .streaming, .offline],
        source: ModelSource(
            provider: .huggingFace,
            repository: "example/remote-qwen",
            artifacts: [
                ModelArtifact(
                    id: "weights",
                    url: URL(string: "https://example.com/model.safetensors")!,
                    relativePath: "model.safetensors",
                    checksum: ModelArtifactChecksum(
                        algorithm: "sha256",
                        value: SHA256.hash(data: Data("weights".utf8)).map { String(format: "%02x", $0) }.joined()
                    )
                )
            ]
        ),
        tags: ["downloadable", "mlx", "remote"]
    )
    let manifest = ModelManifest(id: "remote", models: [remoteModel])
    let loader = ManifestLoader()
    let data = try loader.encoded(manifest)
    let privateKey = Curve25519.Signing.PrivateKey()
    let signatureData = try privateKey.signature(for: data)
    let configuration = LLMKitExampleConfiguration.dynamicRemoteManifest(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: hexString(for: signatureData),
                publicKeyValue: hexString(for: privateKey.publicKey.rawRepresentation)
            )
        ),
        fetchManifestData: { _ in data }
    )
    let viewModel = LLMKitExampleViewModel(configuration: configuration)

    await viewModel.refresh()

    #expect(viewModel.models.contains { $0.id == remoteModel.id })
    #expect(viewModel.downloadableModels.contains { $0.id == remoteModel.id })
    #expect(viewModel.catalogStatus.source == .remoteVerified)
}

@MainActor
@Test func liveHuggingFaceCatalogSurfacesFeaturedRemoteModels() async throws {
    let configuration = LLMKitExampleConfiguration.liveHuggingFaceCatalog(
        fetchCatalogData: { url in
            guard url.absoluteString.contains("Qwen3.5-2B-OptiQ-4bit") else {
                throw URLError(.badURL)
            }

            return Data(
                """
                {
                  "sha": "deadbeef",
                  "siblings": [
                    { "rfilename": "config.json", "size": 128 },
                    { "rfilename": "tokenizer.json", "size": 256 },
                    { "rfilename": "model.safetensors", "size": 1024 },
                    { "rfilename": "README.md", "size": 64 }
                  ]
                }
                """.utf8
            )
        }
    )
    let viewModel = LLMKitExampleViewModel(configuration: configuration)

    await viewModel.refresh()

    #expect(viewModel.models.contains { $0.id.rawValue == "mlx-community.Qwen3.5-2B-OptiQ-4bit" })
    #expect(viewModel.downloadableModels.contains { $0.id.rawValue == "mlx-community.Qwen3.5-2B-OptiQ-4bit" })
    #expect(viewModel.catalogStatus.source == .remoteVerified)
}

@MainActor
@Test func dynamicRemoteManifestConfigurationReportsFallbackStatusWhenRemoteCatalogFails() async throws {
    let configuration = LLMKitExampleConfiguration.dynamicRemoteManifest(
        remoteSource: RemoteModelCatalogSource(
            url: URL(string: "https://example.com/catalog.json")!,
            signature: ModelManifestSignature(
                algorithm: "ed25519",
                value: String(repeating: "0", count: 128),
                publicKeyValue: hexString(for: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation)
            )
        ),
        fetchManifestData: { _ in
            try ManifestLoader().encoded(ModelManifest(
                id: "remote",
                models: [ModelDescriptor(
                    id: "remote.invalid",
                    displayName: "Remote Invalid",
                    family: .qwen,
                    backend: .mlx,
                    capabilities: [.chat],
                    source: ModelSource(
                        provider: .huggingFace,
                        repository: "example/remote-invalid",
                        artifacts: [
                            ModelArtifact(
                                id: "weights",
                                url: URL(string: "https://example.com/model.safetensors")!,
                                relativePath: "model.safetensors"
                            )
                        ]
                    ),
                    tags: ["downloadable", "mlx", "remote"]
                )]
            ))
        }
    )
    let viewModel = LLMKitExampleViewModel(configuration: configuration)

    await viewModel.refresh()

    #expect(viewModel.catalogStatus.source == .fallback)
    #expect(viewModel.models.contains { $0.id == LLMKitExampleModels.qwen25HalfBInstructMLX4Bit.id })
}

@MainActor
@Test func exampleViewModelDefaultsPreferLocalAppleIntelligenceSmokeTest() {
    let viewModel = LLMKitExampleViewModel(configuration: .appleIntelligenceOnly())

    #expect(viewModel.executionMode == .preferOffline)
    #expect(viewModel.privacyMode == .localOnly)
    #expect(viewModel.qualityTier == .balanced)
    #expect(viewModel.maxOutputTokens == 512)
}

@MainActor
@Test func exampleViewModelRestoresPersistedSelectionAndRoutingPreferences() {
    let suiteName = "LLMKitExampleUITests.\(#function)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(LLMKitExampleModels.qwen31Point7BMLX4Bit.id.rawValue, forKey: "llmkit.example.selectedModelID")
    defaults.set(ExecutionMode.remoteAllowed.rawValue, forKey: "llmkit.example.executionMode")
    defaults.set(QualityTier.best.rawValue, forKey: "llmkit.example.qualityTier")
    defaults.set(PrivacyMode.standard.rawValue, forKey: "llmkit.example.privacyMode")
    defaults.set(1024, forKey: "llmkit.example.maxOutputTokens")

    let viewModel = LLMKitExampleViewModel(
        configuration: .localIPhoneCatalog(),
        defaults: defaults
    )

    #expect(viewModel.selectedModelID == LLMKitExampleModels.qwen31Point7BMLX4Bit.id)
    #expect(viewModel.executionMode == .remoteAllowed)
    #expect(viewModel.qualityTier == .best)
    #expect(viewModel.privacyMode == .standard)
    #expect(viewModel.maxOutputTokens == 1024)
}

@MainActor
@Test func exampleViewModelFallsBackToFirstModelWhenPersistedSelectionIsMissing() async {
    let suiteName = "LLMKitExampleUITests.\(#function)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("missing.model", forKey: "llmkit.example.selectedModelID")

    let viewModel = LLMKitExampleViewModel(
        configuration: .appleIntelligenceOnly(),
        defaults: defaults
    )

    await viewModel.refresh()

    #expect(viewModel.selectedModelID == LLMKitExampleModels.appleIntelligence.id)
    #expect(defaults.string(forKey: "llmkit.example.selectedModelID") == LLMKitExampleModels.appleIntelligence.id.rawValue)
}

private func hexString(for data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}
