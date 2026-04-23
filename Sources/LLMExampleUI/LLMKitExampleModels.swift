import LLMCore

public enum LLMKitExampleModels {
    public static let appleIntelligence = ModelDescriptor(
        id: "apple.system.foundation.default",
        displayName: "Apple Intelligence",
        family: .appleFoundation,
        backend: .foundationModels,
        capabilities: [
            .chat,
            .completion,
            .streaming,
            .structuredOutput,
            .summarization,
            .extraction,
            .classification,
            .offline,
            .lowLatency
        ],
        minimumOS: "iOS 26 / macOS 26 / visionOS 26",
        contextWindowTokens: nil,
        supportsStreaming: true,
        supportsTools: false,
        supportsStructuredOutput: true,
        isRemote: false,
        tags: [
            "system-managed",
            "apple-intelligence",
            "example"
        ]
    )
}
