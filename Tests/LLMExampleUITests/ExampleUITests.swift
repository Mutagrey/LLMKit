import CryptoKit
import Foundation
import LLMCore
import LLMExampleUI
import LLMModelLifecycle
import LLMOrchestrator
import LLMProtocols
import LLMStorage
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
    #expect(models.contains { $0.id == LLMKitExampleModels.qwen30Point6BGabliteratedMLX4Bit.id })
    #expect(models.contains { $0.id.rawValue == "mlx-community.Qwen3-1.7B-4bit" })
    #expect(models.contains { $0.id == LLMKitExampleModels.qwen31Point7BAbliteratedMLX4Bit.id })
    #expect(models.contains { $0.id == LLMKitExampleModels.qwen34BSkyHighHermesGabliteratedMLX4Bit.id })
    #expect(models.contains { $0.id.rawValue == "mlx-community.gemma-3-1b-it-4bit" })
}

@Test func localIPhoneCatalogConfiguresDownloadableModelsFromManifest() async throws {
    let configuration = LLMKitExampleConfiguration.localIPhoneCatalog()
    let models = try await configuration.catalog.availableModels()

    #expect(configuration.downloadableModels.count == LLMKitExampleModels.localIPhoneTextModels.count)
    #expect(models.contains { $0.id == LLMKitExampleModels.appleIntelligence.id })
    #expect(models.contains { $0.id == LLMKitExampleModels.qwen34BMLX4Bit.id })
    #expect(configuration.downloadableModels.contains {
        $0.id == LLMKitExampleModels.qwen34BSkyHighHermesGabliteratedMLX4Bit.id
    })
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
@Test func exampleViewModelNormalizesPersistedSelectionToFirstReadyModel() async {
    let suiteName = "LLMKitExampleUITests.\(#function)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let ready = testModel(id: "ready.model", displayName: "Ready Model")
    let notInstalled = testModel(id: "install.model", displayName: "Install Model")
    defaults.set(notInstalled.id.rawValue, forKey: "llmkit.example.selectedModelID")

    let viewModel = LLMKitExampleViewModel(
        configuration: testConfiguration(
            models: [notInstalled, ready],
            readyModelIDs: [ready.id]
        ),
        defaults: defaults
    )

    await viewModel.refresh()

    #expect(viewModel.selectedModelID == ready.id)
    #expect(defaults.string(forKey: "llmkit.example.selectedModelID") == ready.id.rawValue)
}

@MainActor
@Test func exampleViewModelClearsSelectedModelWhenNoReadyModelsExist() async {
    let suiteName = "LLMKitExampleUITests.\(#function)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let notInstalled = testModel(id: "install.model", displayName: "Install Model")
    defaults.set(notInstalled.id.rawValue, forKey: "llmkit.example.selectedModelID")

    let viewModel = LLMKitExampleViewModel(
        configuration: testConfiguration(
            models: [notInstalled],
            readyModelIDs: []
        ),
        defaults: defaults
    )

    await viewModel.refresh()

    #expect(viewModel.selectedModelID == nil)
    #expect(viewModel.selectedModel == nil)
    #expect(!viewModel.canChatWithSelectedModel)
    #expect(defaults.string(forKey: "llmkit.example.selectedModelID") == nil)
}

@MainActor
@Test func chatSelectableModelsExcludeNotInstalledDownloadableModels() async {
    let ready = testModel(id: "ready.model", displayName: "Ready Model")
    let notInstalled = testModel(id: "install.model", displayName: "Install Model")
    let viewModel = LLMKitExampleViewModel(
        configuration: testConfiguration(
            models: [ready, notInstalled],
            readyModelIDs: [ready.id]
        )
    )

    await viewModel.refresh()

    #expect(viewModel.chatSelectableModels.map(\.id) == [ready.id])
    #expect(!viewModel.chatSelectableModels.contains { $0.id == notInstalled.id })
}

@MainActor
@Test func fullModelsCatalogKeepsNotInstalledDownloadableModels() async {
    let ready = testModel(id: "ready.model", displayName: "Ready Model")
    let notInstalled = testModel(id: "install.model", displayName: "Install Model")
    let viewModel = LLMKitExampleViewModel(
        configuration: testConfiguration(
            models: [ready, notInstalled],
            readyModelIDs: [ready.id]
        )
    )

    await viewModel.refresh()

    #expect(viewModel.models.map(\.id).contains(notInstalled.id))
    #expect(viewModel.downloadableModels.map(\.id).contains(notInstalled.id))
}

private func hexString(for data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

@MainActor
@Test func manualSessionsKeepLockedModelSelectionAfterGlobalSelectionChanges() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMExampleUITests")
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let sessionStore = SessionFileStore(paths: StoragePaths(rootDirectory: directory))
    let firstModel = testModel(id: "first.ready", displayName: "First Ready")
    let secondModel = testModel(id: "second.ready", displayName: "Second Ready")
    let configuration = testConfiguration(
        models: [firstModel, secondModel],
        readyModelIDs: [firstModel.id, secondModel.id],
        sessionStore: sessionStore
    )
    let viewModel = LLMKitExampleViewModel(configuration: configuration)

    await viewModel.refresh()
    viewModel.selectedModelID = firstModel.id
    let first = try await viewModel.createManualSession()

    viewModel.selectedModelID = secondModel.id
    let second = try await viewModel.createManualSession()

    let reloadedFirst = try await viewModel.loadSession(id: first.id)
    let reloadedSecond = try await viewModel.loadSession(id: second.id)

    #expect(reloadedFirst?.executionRequirements?.selectionPolicy == .require(firstModel.id))
    #expect(reloadedSecond?.executionRequirements?.selectionPolicy == .require(secondModel.id))
}

@MainActor
@Test func persistedSessionsAreRestoredIntoNewViewModelInstances() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LLMExampleUITests")
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let sessionStore = SessionFileStore(paths: StoragePaths(rootDirectory: directory))
    let readyModel = testModel(id: "ready.model", displayName: "Ready Model")
    let configuration = testConfiguration(
        models: [readyModel],
        readyModelIDs: [readyModel.id],
        sessionStore: sessionStore
    )
    let firstViewModel = LLMKitExampleViewModel(configuration: configuration)

    await firstViewModel.refresh()
    _ = try await firstViewModel.createManualSession()
    let automationRequirements = firstViewModel.requirements(
        for: readyModel,
        preferredLatency: .background
    )
    let definition = AutomatedConversationDefinition(
        topic: "Persisted automation",
        participants: [
            AutomatedConversationParticipant(
                id: "speaker-a",
                displayName: "Planner",
                role: "Open the discussion."
            )
        ],
        sharedExecutionRequirements: automationRequirements,
        maxTurns: 4
    )
    _ = try await firstViewModel.createAutomatedSession(
        title: "Automation",
        definition: definition,
        executionRequirements: automationRequirements
    )

    let secondViewModel = LLMKitExampleViewModel(configuration: configuration)
    await secondViewModel.refresh()

    #expect(secondViewModel.sessions.count == 2)
    #expect(secondViewModel.sessions.contains { $0.kind == .manualChat })
    #expect(secondViewModel.sessions.contains { $0.kind == .automatedConversation })
}

private let testBackendKind = BackendKind.custom("test")

private func testModel(id: ModelID, displayName: String) -> ModelDescriptor {
    ModelDescriptor(
        id: id,
        displayName: displayName,
        family: .custom("test"),
        backend: testBackendKind,
        capabilities: [.chat, .completion, .streaming, .offline],
        tags: ["downloadable", "test"]
    )
}

private func testConfiguration(
    models: [ModelDescriptor],
    readyModelIDs: Set<ModelID>,
    sessionStore: (any SessionStore)? = nil
) -> LLMKitExampleConfiguration {
    let catalog = DefaultModelCatalog(manifest: ModelManifest(id: "test.catalog", models: models))
    let backend = StaticAvailabilityBackend(readyModelIDs: readyModelIDs)
    let lifecycle = StaticLifecycleService(models: models, readyModelIDs: readyModelIDs)
    let container = LLMKitFactory.makeContainer(
        catalog: catalog,
        backends: [backend],
        lifecycle: lifecycle,
        sessionStore: sessionStore
    )
    return LLMKitExampleConfiguration(
        container: container,
        catalog: catalog,
        backends: [backend],
        downloadableModels: models.filter { $0.tags.contains("downloadable") },
        sessionStore: sessionStore
    )
}

private struct StaticAvailabilityBackend: ModelBackend {
    let backendKind = testBackendKind
    let readyModelIDs: Set<ModelID>

    func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard descriptor.backend == backendKind else {
            return .unsupported
        }
        return readyModelIDs.contains(descriptor.id)
            ? .available
            : BackendAvailability(status: .requiresInstall)
    }

    func supports(_ capability: ModelCapability, model: ModelDescriptor) -> Bool {
        model.backend == backendKind && model.capabilities.contains(capability)
    }

    func loadModel(_ descriptor: ModelDescriptor) async throws -> LoadedModelHandle {
        LoadedModelHandle(id: descriptor.id, backend: descriptor.backend)
    }

    func unloadModel(_ handle: LoadedModelHandle) async {}

    func generate(_ request: BackendGenerationRequest) -> AsyncThrowingStream<BackendGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.completed(GenerationResult(text: "ok", model: request.model)))
            continuation.finish()
        }
    }

    func chat(_ request: BackendChatRequest) -> AsyncThrowingStream<BackendChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let message = ChatMessage(role: .assistant, content: MessageContent(text: "ok"))
            continuation.yield(.completed(ChatResult(message: message, model: request.model)))
            continuation.finish()
        }
    }
}

private struct StaticLifecycleService: ModelLifecycleService {
    let models: [ModelDescriptor]
    let readyModelIDs: Set<ModelID>

    func installedModels() async throws -> [InstalledModelRecord] {
        models
            .filter { readyModelIDs.contains($0.id) }
            .map { InstalledModelRecord(descriptor: $0, installState: .ready) }
    }

    func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func state(for modelID: ModelID) async throws -> InstallState {
        readyModelIDs.contains(modelID) ? .ready : .notInstalled
    }
}
