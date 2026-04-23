import Foundation
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

    public static let qwen25HalfBInstructMLX4Bit = ModelDescriptor(
        id: "mlx-community.Qwen2.5-0.5B-Instruct-4bit",
        displayName: "Qwen2.5 0.5B Instruct 4-bit",
        family: .qwen,
        backend: .mlx,
        capabilities: [
            .chat,
            .completion,
            .streaming,
            .offline,
            .lowLatency
        ],
        minimumRAMGB: 4,
        minimumFreeDiskGB: 1,
        contextWindowTokens: 32768,
        supportsStreaming: true,
        supportsTools: false,
        supportsStructuredOutput: false,
        isRemote: false,
        source: ModelSource(
            provider: .huggingFace,
            repository: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            homepageURL: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-0.5B-Instruct-4bit"),
            artifacts: [
                artifact("added_tokens.json"),
                artifact("config.json"),
                artifact("merges.txt"),
                artifact("model.safetensors"),
                artifact("model.safetensors.index.json"),
                artifact("special_tokens_map.json"),
                artifact("tokenizer.json"),
                artifact("tokenizer_config.json"),
                artifact("vocab.json")
            ]
        ),
        license: ModelLicense(
            name: "Apache License 2.0",
            spdxIdentifier: "Apache-2.0",
            url: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")
        ),
        quantization: Quantization(format: "MLX 4-bit", bits: 4),
        estimatedDownloadSizeBytes: 290_000_000,
        tags: [
            "downloadable",
            "mlx",
            "qwen",
            "smoke-test"
        ]
    )

    private static func artifact(_ path: String) -> ModelArtifact {
        ModelArtifact(
            id: path,
            url: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-0.5B-Instruct-4bit/resolve/main/\(path)")!,
            relativePath: path
        )
    }
}
