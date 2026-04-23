import LLMBackendFoundationModels
import LLMBackendMLX
import LLMCore
import LLMExampleUI
import LLMModelLifecycle
import LLMOrchestrator
import LLMProtocols

enum DemoConfiguration {
    static func make() -> LLMKitExampleConfiguration {
        let downloadableModels = [
            LLMKitExampleModels.qwen25HalfBInstructMLX4Bit
        ]
        let models = [
            LLMKitExampleModels.appleIntelligence,
            demoEchoModel
        ] + downloadableModels
        let catalog = DefaultModelCatalog(models: models)
        let backends: [any ModelBackend] = [
            FoundationModelsBackend(),
            MLXBackend(runtimeAvailable: true),
            DemoEchoBackend()
        ]
        let container = LLMKitFactory.makeContainer(
            catalog: catalog,
            backends: backends
        )

        return LLMKitExampleConfiguration(
            container: container,
            catalog: catalog,
            backends: backends,
            downloadableModels: downloadableModels
        )
    }

    private static let demoEchoModel = ModelDescriptor(
        id: "demo.echo",
        displayName: "Demo Echo",
        family: .custom("demo"),
        backend: .custom("demo"),
        capabilities: [
            .chat,
            .completion,
            .streaming,
            .offline,
            .lowLatency
        ],
        contextWindowTokens: 4096,
        supportsStreaming: true,
        tags: [
            "demo",
            "simulator-safe"
        ]
    )
}
