import Foundation
import LLMCore

public enum CuratedModelManifests {
    public static let appleFoundation = ModelManifest(
        id: "llmkit.apple.foundation",
        models: [appleIntelligence]
    )

    public static let localIPhoneTextModels = ModelManifest(
        id: "llmkit.local.iphone-text-models",
        models: [
            gemma4E2BInstructionMLX4Bit,
            qwen25HalfBInstructMLX4Bit,
            qwen30Point6BMLX4Bit,
            qwen31Point7BMLX4Bit,
            gemma31BInstructionMLX4Bit,
            qwen34BMLX4Bit
        ]
    )

    public static func combinedExampleCatalog() -> ModelManifest {
        merged(
            id: "llmkit.example.catalog",
            manifests: [appleFoundation, localIPhoneTextModels]
        )
    }

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
        supportsStreaming: true,
        supportsStructuredOutput: true,
        tags: [
            "system-managed",
            "apple-intelligence",
            "example"
        ]
    )

    public static let qwen25HalfBInstructMLX4Bit = qwenModel(
        id: "mlx-community.Qwen2.5-0.5B-Instruct-4bit",
        displayName: "Qwen2.5 0.5B Instruct 4-bit",
        repository: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        revision: "a5339a4131f135d0fdc6a5c8b5bbed2753bbe0f3",
        minimumRAMGB: 4,
        minimumFreeDiskGB: 1,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 278_064_920,
        tags: ["starter", "smoke-test", "iphone-entry"]
    )

    public static let qwen30Point6BMLX4Bit = qwenModel(
        id: "mlx-community.Qwen3-0.6B-4bit",
        displayName: "Qwen3 0.6B 4-bit",
        repository: "mlx-community/Qwen3-0.6B-4bit",
        revision: "73e3e38d981303bc594367cd910ea6eb48349da8",
        minimumRAMGB: 4,
        minimumFreeDiskGB: 1,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 682_323_786,
        tags: ["starter", "iphone-entry"]
    )

    public static let qwen31Point7BMLX4Bit = qwenModel(
        id: "mlx-community.Qwen3-1.7B-4bit",
        displayName: "Qwen3 1.7B 4-bit",
        repository: "mlx-community/Qwen3-1.7B-4bit",
        revision: "3b1b1768f8f8cf8351c712464f906e86c2b8269e",
        minimumRAMGB: 6,
        minimumFreeDiskGB: 2,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 979_502_864,
        tags: ["balanced", "iphone-recommended"]
    )

    public static let qwen34BMLX4Bit = qwenModel(
        id: "mlx-community.Qwen3-4B-4bit",
        displayName: "Qwen3 4B 4-bit",
        repository: "mlx-community/Qwen3-4B-4bit",
        revision: "4dcb3d101c2a062e5c1d4bb173588c54ea6c4d25",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 4,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 2_274_445_183,
        tags: ["quality", "iphone-pro"]
    )

    public static let gemma31BInstructionMLX4Bit = gemmaTextModel(
        id: "mlx-community.gemma-3-1b-it-4bit",
        displayName: "Gemma 3 1B Instruct 4-bit",
        repository: "mlx-community/gemma-3-1b-it-4bit",
        revision: "2d44e83dc9e80843d22fb941d3d699a0b1351aa6",
        minimumRAMGB: 6,
        minimumFreeDiskGB: 2,
        estimatedDownloadSizeBytes: 770_650_946,
        tags: ["balanced", "iphone-recommended"]
    )

    public static let gemma4E2BInstructionMLX4Bit = gemma4TextModel(
        id: "mlx-community.gemma-4-e2b-it-4bit",
        displayName: "Gemma 4 E2B Instruct 4-bit",
        repository: "mlx-community/gemma-4-e2b-it-4bit",
        revision: "99d9a53ff828d365a8ecae538e45f80a08d612cd",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 5,
        contextWindowTokens: 131_072,
        estimatedDownloadSizeBytes: 3_843_248_947,
        tags: ["quality", "iphone-pro", "gemma4", "agentic"]
    )

    public static func merged(id: String, manifests: [ModelManifest]) -> ModelManifest {
        let models = manifests
            .flatMap(\.models)
            .reduce(into: [ModelID: ModelDescriptor]()) { partialResult, descriptor in
                partialResult[descriptor.id] = descriptor
            }
            .values
            .sorted { $0.displayName < $1.displayName }
        return ModelManifest(id: id, models: models)
    }

    private static func qwenModel(
        id: ModelID,
        displayName: String,
        repository: String,
        revision: String,
        minimumRAMGB: Int,
        minimumFreeDiskGB: Int,
        contextWindowTokens: Int,
        estimatedDownloadSizeBytes: Int64,
        tags: [String]
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            displayName: displayName,
            family: .qwen,
            backend: .mlx,
            capabilities: [
                .chat,
                .completion,
                .streaming,
                .offline,
                .lowLatency
            ],
            minimumRAMGB: minimumRAMGB,
            minimumFreeDiskGB: minimumFreeDiskGB,
            contextWindowTokens: contextWindowTokens,
            supportsStreaming: true,
            source: pinnedSource(
                repository: repository,
                revision: revision,
                artifacts: qwenArtifacts
            ),
            license: apacheTwoLicense(repositoryOwner: repository),
            quantization: Quantization(format: "MLX 4-bit", bits: 4),
            estimatedDownloadSizeBytes: estimatedDownloadSizeBytes,
            tags: baseLocalTags + ["qwen"] + tags
        )
    }

    private static func gemmaTextModel(
        id: ModelID,
        displayName: String,
        repository: String,
        revision: String,
        minimumRAMGB: Int,
        minimumFreeDiskGB: Int,
        estimatedDownloadSizeBytes: Int64,
        tags: [String]
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            displayName: displayName,
            family: .gemma,
            backend: .mlx,
            capabilities: [
                .chat,
                .completion,
                .streaming,
                .offline,
                .lowLatency
            ],
            minimumRAMGB: minimumRAMGB,
            minimumFreeDiskGB: minimumFreeDiskGB,
            contextWindowTokens: 32768,
            supportsStreaming: true,
            source: pinnedSource(
                repository: repository,
                revision: revision,
                artifacts: gemmaTextArtifacts
            ),
            license: gemmaLicense,
            quantization: Quantization(format: "MLX 4-bit", bits: 4),
            estimatedDownloadSizeBytes: estimatedDownloadSizeBytes,
            tags: baseLocalTags + ["gemma"] + tags
        )
    }

    private static func gemma4TextModel(
        id: ModelID,
        displayName: String,
        repository: String,
        revision: String,
        minimumRAMGB: Int,
        minimumFreeDiskGB: Int,
        contextWindowTokens: Int,
        estimatedDownloadSizeBytes: Int64,
        tags: [String]
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            displayName: displayName,
            family: .gemma,
            backend: .mlx,
            capabilities: [
                .chat,
                .completion,
                .streaming,
                .offline,
                .lowLatency,
                .longContext
            ],
            minimumRAMGB: minimumRAMGB,
            minimumFreeDiskGB: minimumFreeDiskGB,
            contextWindowTokens: contextWindowTokens,
            supportsStreaming: true,
            source: pinnedSource(
                repository: repository,
                revision: revision,
                artifacts: gemma4TextArtifacts
            ),
            license: apacheTwoLicense(repositoryOwner: repository),
            quantization: Quantization(format: "MLX 4-bit", bits: 4),
            estimatedDownloadSizeBytes: estimatedDownloadSizeBytes,
            tags: baseLocalTags + ["gemma"] + tags
        )
    }

    private static func pinnedSource(
        repository: String,
        revision: String,
        artifacts: [String]
    ) -> ModelSource {
        ModelSource(
            provider: .huggingFace,
            repository: repository,
            revision: revision,
            homepageURL: URL(string: "https://huggingface.co/\(repository)"),
            artifacts: artifacts.map { artifactPath in
                ModelArtifact(
                    id: artifactPath,
                    url: URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(artifactPath)")!,
                    relativePath: artifactPath
                )
            }
        )
    }

    private static func apacheTwoLicense(repositoryOwner repository: String) -> ModelLicense {
        ModelLicense(
            name: "Apache License 2.0",
            spdxIdentifier: "Apache-2.0",
            url: URL(string: "https://huggingface.co/\(repository)/blob/main/LICENSE")
        )
    }

    private static let gemmaLicense = ModelLicense(
        name: "Gemma License",
        url: URL(string: "https://ai.google.dev/gemma/terms")
    )

    private static let baseLocalTags = [
        "downloadable",
        "mlx",
        "local",
        "iphone"
    ]

    private static let qwenArtifacts = [
        "added_tokens.json",
        "config.json",
        "merges.txt",
        "model.safetensors",
        "model.safetensors.index.json",
        "special_tokens_map.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "vocab.json"
    ]

    private static let gemmaTextArtifacts = [
        "added_tokens.json",
        "config.json",
        "model.safetensors",
        "model.safetensors.index.json",
        "preprocessor_config.json",
        "special_tokens_map.json",
        "tokenizer.json",
        "tokenizer.model",
        "tokenizer_config.json"
    ]

    private static let gemma4TextArtifacts = [
        "chat_template.jinja",
        "config.json",
        "generation_config.json",
        "model.safetensors",
        "model.safetensors.index.json",
        "processor_config.json",
        "tokenizer.json",
        "tokenizer_config.json"
    ]
}
