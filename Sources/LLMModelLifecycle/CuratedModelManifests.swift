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
            qwen35Point8BOptiQMLX4Bit,
            qwen35TwoBOptiQMLX4Bit,
            qwen31Point7BAbliteratedMLX4Bit,
            gemma4E2BInstructionMLX4Bit,
            llama32ThreeBInstructUncensoredMLX6Bit
        ]
    )

    public static let localIPhoneGGUFTextModels = ModelManifest(
        id: "llmkit.local.iphone-gguf-text-models",
        models: [
            gemma31BInstructionGGUFQ4KM,
            llama32OneBInstructGGUFQ4KM,
            gemma34BInstructionGGUFQ4KM,
            gemma4E2BInstructionGGUFQ4KM,
            qwen34BInstruct2507GGUFQ4KM,
            qwen38BGGUFQ4KM,
            qwen34BHereticGGUFQ4KM,
            metaLlama31EightBInstructAbliteratedGGUFQ4KM
        ]
    )

    public static func combinedExampleCatalog() -> ModelManifest {
        merged(
            id: "llmkit.example.catalog",
            manifests: [appleFoundation, localIPhoneTextModels, localIPhoneGGUFTextModels]
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

    public static let qwen35Point8BOptiQMLX4Bit = qwenModel(
        id: "mlx-community.Qwen3.5-0.8B-OptiQ-4bit",
        displayName: "Qwen3.5 0.8B OptiQ 4-bit",
        repository: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
        revision: "d46340b3af35798ffa8f63a8ad72afed038b234a",
        minimumRAMGB: 4,
        minimumFreeDiskGB: 1,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 650_257_188,
        artifacts: qwenOptiQArtifacts,
        tags: ["starter", "iphone-entry", "optiq", "latest"]
    )

    public static let qwen35TwoBOptiQMLX4Bit = qwenModel(
        id: "mlx-community.Qwen3.5-2B-OptiQ-4bit",
        displayName: "Qwen3.5 2B OptiQ 4-bit",
        repository: "mlx-community/Qwen3.5-2B-OptiQ-4bit",
        revision: "dc9f6362624807ba8b11ec40df10474c1d467f77",
        minimumRAMGB: 6,
        minimumFreeDiskGB: 2,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 1_533_885_748,
        artifacts: qwenOptiQArtifacts,
        tags: ["balanced", "iphone-recommended", "optiq", "latest"]
    )

    public static let qwen35FourBOptiQMLX4Bit = qwenModel(
        id: "mlx-community.Qwen3.5-4B-OptiQ-4bit",
        displayName: "Qwen3.5 4B OptiQ 4-bit",
        repository: "mlx-community/Qwen3.5-4B-OptiQ-4bit",
        revision: "fecba971a2d0cd02b6b025862c1aaa7d2e3dad15",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 4,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 3_269_669_552,
        artifacts: qwenOptiQArtifacts,
        tags: ["quality", "iphone-pro", "optiq", "latest"]
    )

    public static let qwen30Point6BGabliteratedMLX4Bit = qwenModel(
        id: "mlx-community.Qwen3-0.6B-gabliterated-4bit",
        displayName: "Qwen3 0.6B Gabliterated 4-bit",
        repository: "mlx-community/Qwen3-0.6B-gabliterated-4bit",
        revision: "7c4366720cfe5fb2a3a0802ed9d712cfc3b1b955",
        minimumRAMGB: 4,
        minimumFreeDiskGB: 1,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 347_000_000,
        artifacts: qwenChatTemplateArtifacts,
        tags: ["experimental", "uncensored", "gabliterated"]
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

    public static let qwen31Point7BAbliteratedMLX4Bit = qwenModel(
        id: "mlx-community.Josiefied-Qwen3-1.7B-abliterated-v1-4bit",
        displayName: "Qwen3 1.7B Abliterated 4-bit",
        repository: "mlx-community/Josiefied-Qwen3-1.7B-abliterated-v1-4bit",
        revision: "d3d25b1ab4aab996965239f3cd1e8a1887e97d30",
        minimumRAMGB: 6,
        minimumFreeDiskGB: 2,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 984_000_000,
        tags: ["experimental", "uncensored", "abliterated"]
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

    public static let qwen34BInstruct2507MLX4Bit = qwenModel(
        id: "mlx-community.Qwen3-4B-Instruct-2507-4bit",
        displayName: "Qwen3 4B Instruct 2507 4-bit",
        repository: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
        revision: "50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 4,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 2_263_022_417,
        artifacts: qwenInstructArtifacts,
        tags: ["quality", "iphone-pro", "instruct", "latest"]
    )

    public static let josiefiedQwen38BAbliteratedMLX4Bit = qwenModel(
        id: "mlx-community.Josiefied-Qwen3-8B-abliterated-v1-4bit",
        displayName: "Qwen3 8B Abliterated 4-bit",
        repository: "mlx-community/Josiefied-Qwen3-8B-abliterated-v1-4bit",
        revision: "82a8d731dc4f724f2c908090b5949984cf5a6348",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 5,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 4_607_835_164,
        tags: ["quality", "iphone-pro", "experimental", "uncensored", "abliterated"]
    )

    public static let qwen25SevenBInstructUncensoredMLX4Bit = qwenModel(
        id: "mlx-community.Qwen2.5-7B-Instruct-Uncensored-4bit",
        displayName: "Qwen2.5 7B Instruct Uncensored 4-bit",
        repository: "mlx-community/Qwen2.5-7B-Instruct-Uncensored-4bit",
        revision: "1d8b6a0dd6a659bb6c8711be60f993682e5c83f1",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 5,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 4_284_346_187,
        license: ModelLicense(
            name: "GNU General Public License v3.0",
            spdxIdentifier: "GPL-3.0",
            url: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-7B-Instruct-Uncensored-4bit/blob/main/LICENSE")
        ),
        tags: ["quality", "iphone-pro", "uncensored", "gpl-3.0"]
    )

    public static let qwen34BSkyHighHermesGabliteratedMLX4Bit = qwenModel(
        id: "mlx-community.Qwen3-4B-Sky-High-Hermes-gabliterated-4bit",
        displayName: "Qwen3 4B Sky High Hermes Gabliterated 4-bit",
        repository: "mlx-community/Qwen3-4B-Sky-High-Hermes-gabliterated-4bit",
        revision: "312009c7dc51cdf5b87b3e16701fd0441391205a",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 4,
        contextWindowTokens: 32768,
        estimatedDownloadSizeBytes: 2_270_000_000,
        artifacts: qwenChatTemplateArtifacts,
        tags: ["experimental", "uncensored", "gabliterated"]
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

    public static let gemma4E2BInstructionOptiQMLX4Bit = gemma4TextModel(
        id: "mlx-community.gemma-4-e2b-it-OptiQ-4bit",
        displayName: "Gemma 4 E2B Instruct OptiQ 4-bit",
        repository: "mlx-community/gemma-4-e2b-it-OptiQ-4bit",
        revision: "789c0188f6ea14f6543101ef509e02b3cfb432ab",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 5,
        contextWindowTokens: 131_072,
        estimatedDownloadSizeBytes: 4_296_816_768,
        tags: ["quality", "iphone-pro", "gemma4", "agentic", "optiq", "latest"]
    )

    public static let llama32OneBInstructMLX4Bit = llamaModel(
        id: "mlx-community.Llama-3.2-1B-Instruct-4bit",
        displayName: "Llama 3.2 1B Instruct 4-bit",
        repository: "mlx-community/Llama-3.2-1B-Instruct-4bit",
        revision: "08231374eeacb049a0eade7922910865b8fce912",
        minimumRAMGB: 4,
        minimumFreeDiskGB: 1,
        contextWindowTokens: 131_072,
        estimatedDownloadSizeBytes: 695_283_921,
        tags: ["starter", "iphone-entry"]
    )

    public static let llama32ThreeBInstructMLX4Bit = llamaModel(
        id: "mlx-community.Llama-3.2-3B-Instruct-4bit",
        displayName: "Llama 3.2 3B Instruct 4-bit",
        repository: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        revision: "7f0dc925e0d0afb0322d96f9255cfddf2ba5636e",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 3,
        contextWindowTokens: 131_072,
        estimatedDownloadSizeBytes: 1_807_496_278,
        tags: ["balanced", "iphone-recommended"]
    )

    public static let llama32ThreeBInstructUncensoredMLX6Bit = llamaModel(
        id: "mlx-community.Llama-3.2-3B-Instruct-uncensored-6bit",
        displayName: "Llama 3.2 3B Instruct Uncensored 6-bit",
        repository: "mlx-community/Llama-3.2-3B-Instruct-uncensored-6bit",
        revision: "3aba7aeea6314641a6110edd1ef40e49ad941033",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 3,
        contextWindowTokens: 131_072,
        estimatedDownloadSizeBytes: 2_610_640_196,
        quantization: Quantization(format: "MLX 6-bit", bits: 6),
        tags: ["balanced", "iphone-pro", "uncensored"]
    )

    public static let metaLlama31EightBInstructAbliteratedMLX4Bit = llamaModel(
        id: "mlx-community.Meta-Llama-3.1-8B-Instruct-abliterated-4bit",
        displayName: "Llama 3.1 8B Instruct Abliterated 4-bit",
        repository: "mlx-community/Meta-Llama-3.1-8B-Instruct-abliterated-4bit",
        revision: "4d161a4206d3a408bc942effa61dbfff4febe63c",
        minimumRAMGB: 8,
        minimumFreeDiskGB: 5,
        contextWindowTokens: 131_072,
        estimatedDownloadSizeBytes: 4_517_489_037,
        tags: ["quality", "iphone-pro", "uncensored", "abliterated"]
    )

    public static let llama32OneBInstructGGUFQ4KM = llamaGGUFModel(
        id: "bartowski.Llama-3.2-1B-Instruct-GGUF.Q4_K_M",
        displayName: "Llama 3.2 1B Instruct GGUF Q4_K_M",
        repository: "bartowski/Llama-3.2-1B-Instruct-GGUF",
        revision: "067b946cf014b7c697f3654f621d577a3e3afd1c",
        fileName: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
        byteCount: 807_694_464,
        minimumRAMGB: 4,
        minimumFreeDiskGB: 1,
        contextWindowTokens: 131_072,
        tags: ["starter", "iphone-entry"]
    )

    public static let gemma31BInstructionGGUFQ4KM = gemmaGGUFModel(
        id: "bartowski.google_gemma-3-1b-it-GGUF.Q4_K_M",
        displayName: "Gemma 3 1B Instruct GGUF Q4_K_M",
        repository: "bartowski/google_gemma-3-1b-it-GGUF",
        revision: "116f76234503685a98f572982177b11d44ec8ff1",
        fileName: "google_gemma-3-1b-it-Q4_K_M.gguf",
        byteCount: 806_058_496,
        minimumRAMGB: 4,
        minimumFreeDiskGB: 1,
        contextWindowTokens: 32_768,
        tags: ["starter", "iphone-entry", "gemma3"]
    )

    public static let gemma34BInstructionGGUFQ4KM = gemmaGGUFModel(
        id: "bartowski.google_gemma-3-4b-it-GGUF.Q4_K_M",
        displayName: "Gemma 3 4B Instruct GGUF Q4_K_M",
        repository: "bartowski/google_gemma-3-4b-it-GGUF",
        revision: "71506238f970075ca85125cd749c28b1b0eee84e",
        fileName: "google_gemma-3-4b-it-Q4_K_M.gguf",
        byteCount: 2_489_758_112,
        minimumRAMGB: 8,
        minimumFreeDiskGB: 3,
        contextWindowTokens: 131_072,
        tags: ["balanced", "iphone-recommended", "gemma3", "vision-capable-model-text-only"]
    )

    public static let gemma4E2BInstructionGGUFQ4KM = gemmaGGUFModel(
        id: "bartowski.google_gemma-4-E2B-it-GGUF.Q4_K_M",
        displayName: "Gemma 4 E2B Instruct GGUF Q4_K_M",
        repository: "bartowski/google_gemma-4-E2B-it-GGUF",
        revision: "b5e99bd964eaacc27ba484bb2eb3e9f6160b9143",
        fileName: "google_gemma-4-E2B-it-Q4_K_M.gguf",
        byteCount: 3_462_678_272,
        minimumRAMGB: 8,
        minimumFreeDiskGB: 4,
        contextWindowTokens: 131_072,
        tags: ["quality", "iphone-pro", "gemma4", "agentic", "vision-capable-model-text-only"]
    )

    public static let qwen34BInstruct2507GGUFQ4KM = qwenGGUFModel(
        id: "bartowski.Qwen_Qwen3-4B-Instruct-2507-GGUF.Q4_K_M",
        displayName: "Qwen3 4B Instruct 2507 GGUF Q4_K_M",
        repository: "bartowski/Qwen_Qwen3-4B-Instruct-2507-GGUF",
        revision: "ae44f08e1392f39c0e474af10c3ff8355c8b6688",
        fileName: "Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
        byteCount: 2_497_280_736,
        minimumRAMGB: 8,
        minimumFreeDiskGB: 3,
        contextWindowTokens: 32_768,
        tags: ["balanced", "iphone-recommended", "instruct"]
    )

    public static let qwen38BGGUFQ4KM = qwenGGUFModel(
        id: "bartowski.Qwen_Qwen3-8B-GGUF.Q4_K_M",
        displayName: "Qwen3 8B GGUF Q4_K_M",
        repository: "bartowski/Qwen_Qwen3-8B-GGUF",
        revision: "0b69f75b7472688e6808490aa2b85efdb81b5ce7",
        fileName: "Qwen_Qwen3-8B-Q4_K_M.gguf",
        byteCount: 5_027_784_224,
        minimumRAMGB: 8,
        minimumFreeDiskGB: 6,
        contextWindowTokens: 32_768,
        tags: ["large", "iphone-pro"]
    )

    public static let qwen34BHereticGGUFQ4KM = qwenGGUFModel(
        id: "bartowski.p-e-w_Qwen3-4B-Instruct-2507-heretic-GGUF.Q4_K_M",
        displayName: "Qwen3 4B Heretic GGUF Q4_K_M",
        repository: "bartowski/p-e-w_Qwen3-4B-Instruct-2507-heretic-GGUF",
        revision: "374467f099f99156987afeeea6df5bc1f090ff4b",
        fileName: "p-e-w_Qwen3-4B-Instruct-2507-heretic-Q4_K_M.gguf",
        byteCount: 2_497_279_424,
        minimumRAMGB: 8,
        minimumFreeDiskGB: 3,
        contextWindowTokens: 32_768,
        tags: ["experimental", "uncensored", "heretic"]
    )

    public static let metaLlama31EightBInstructAbliteratedGGUFQ4KM = llamaGGUFModel(
        id: "bartowski.Meta-Llama-3.1-8B-Instruct-abliterated-GGUF.Q4_K_M",
        displayName: "Llama 3.1 8B Instruct Abliterated GGUF Q4_K_M",
        repository: "bartowski/Meta-Llama-3.1-8B-Instruct-abliterated-GGUF",
        revision: "c20a902bc96dd611ea0ea396d3ffc290f88c5864",
        fileName: "Meta-Llama-3.1-8B-Instruct-abliterated-Q4_K_M.gguf",
        byteCount: 4_920_734_720,
        minimumRAMGB: 8,
        minimumFreeDiskGB: 5,
        contextWindowTokens: 131_072,
        tags: ["large", "iphone-pro", "uncensored", "abliterated"]
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
        artifacts: [String] = qwenArtifacts,
        license: ModelLicense? = nil,
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
                artifacts: artifacts
            ),
            license: license ?? apacheTwoLicense(repositoryOwner: repository),
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
            license: gemmaLicense,
            quantization: Quantization(format: "MLX 4-bit", bits: 4),
            estimatedDownloadSizeBytes: estimatedDownloadSizeBytes,
            tags: baseLocalTags + ["gemma"] + tags
        )
    }

    private static func llamaModel(
        id: ModelID,
        displayName: String,
        repository: String,
        revision: String,
        minimumRAMGB: Int,
        minimumFreeDiskGB: Int,
        contextWindowTokens: Int,
        estimatedDownloadSizeBytes: Int64,
        quantization: Quantization = Quantization(format: "MLX 4-bit", bits: 4),
        tags: [String]
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            displayName: displayName,
            family: .llama,
            backend: .mlx,
            capabilities: [
                .chat,
                .completion,
                .streaming,
                .offline,
                .longContext
            ],
            minimumRAMGB: minimumRAMGB,
            minimumFreeDiskGB: minimumFreeDiskGB,
            contextWindowTokens: contextWindowTokens,
            supportsStreaming: true,
            source: pinnedSource(
                repository: repository,
                revision: revision,
                artifacts: llamaTextArtifacts
            ),
            license: llamaLicense(repository: repository),
            quantization: quantization,
            estimatedDownloadSizeBytes: estimatedDownloadSizeBytes,
            tags: baseLocalTags + ["llama"] + tags
        )
    }

    private static func llamaGGUFModel(
        id: ModelID,
        displayName: String,
        repository: String,
        revision: String,
        fileName: String,
        byteCount: Int64,
        minimumRAMGB: Int,
        minimumFreeDiskGB: Int,
        contextWindowTokens: Int,
        quantization: Quantization = Quantization(format: "GGUF Q4_K_M", bits: 4),
        tags: [String]
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            displayName: displayName,
            family: .llama,
            backend: .llamaCpp,
            capabilities: [
                .chat,
                .completion,
                .streaming,
                .offline,
                .longContext
            ],
            minimumRAMGB: minimumRAMGB,
            minimumFreeDiskGB: minimumFreeDiskGB,
            contextWindowTokens: contextWindowTokens,
            supportsStreaming: true,
            source: ggufSource(
                repository: repository,
                revision: revision,
                fileName: fileName,
                byteCount: byteCount
            ),
            license: llamaLicense(repository: repository),
            quantization: quantization,
            estimatedDownloadSizeBytes: byteCount,
            tags: baseGGUFLocalTags + ["llama"] + tags
        )
    }

    private static func qwenGGUFModel(
        id: ModelID,
        displayName: String,
        repository: String,
        revision: String,
        fileName: String,
        byteCount: Int64,
        minimumRAMGB: Int,
        minimumFreeDiskGB: Int,
        contextWindowTokens: Int,
        quantization: Quantization = Quantization(format: "GGUF Q4_K_M", bits: 4),
        tags: [String]
    ) -> ModelDescriptor {
        ggufModel(
            id: id,
            displayName: displayName,
            family: .qwen,
            repository: repository,
            revision: revision,
            fileName: fileName,
            byteCount: byteCount,
            minimumRAMGB: minimumRAMGB,
            minimumFreeDiskGB: minimumFreeDiskGB,
            contextWindowTokens: contextWindowTokens,
            license: apacheTwoLicense(repositoryOwner: repository),
            quantization: quantization,
            tags: baseGGUFLocalTags + ["qwen"] + tags
        )
    }

    private static func gemmaGGUFModel(
        id: ModelID,
        displayName: String,
        repository: String,
        revision: String,
        fileName: String,
        byteCount: Int64,
        minimumRAMGB: Int,
        minimumFreeDiskGB: Int,
        contextWindowTokens: Int,
        quantization: Quantization = Quantization(format: "GGUF Q4_K_M", bits: 4),
        tags: [String]
    ) -> ModelDescriptor {
        ggufModel(
            id: id,
            displayName: displayName,
            family: .gemma,
            repository: repository,
            revision: revision,
            fileName: fileName,
            byteCount: byteCount,
            minimumRAMGB: minimumRAMGB,
            minimumFreeDiskGB: minimumFreeDiskGB,
            contextWindowTokens: contextWindowTokens,
            license: gemmaLicense,
            quantization: quantization,
            tags: baseGGUFLocalTags + ["gemma"] + tags
        )
    }

    private static func ggufModel(
        id: ModelID,
        displayName: String,
        family: ModelFamily,
        repository: String,
        revision: String,
        fileName: String,
        byteCount: Int64,
        minimumRAMGB: Int,
        minimumFreeDiskGB: Int,
        contextWindowTokens: Int,
        license: ModelLicense,
        quantization: Quantization,
        tags: [String]
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            displayName: displayName,
            family: family,
            backend: .llamaCpp,
            capabilities: [
                .chat,
                .completion,
                .streaming,
                .offline,
                .longContext
            ],
            minimumRAMGB: minimumRAMGB,
            minimumFreeDiskGB: minimumFreeDiskGB,
            contextWindowTokens: contextWindowTokens,
            supportsStreaming: true,
            source: ggufSource(
                repository: repository,
                revision: revision,
                fileName: fileName,
                byteCount: byteCount
            ),
            license: license,
            quantization: quantization,
            estimatedDownloadSizeBytes: byteCount,
            tags: tags
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

    private static func ggufSource(
        repository: String,
        revision: String,
        fileName: String,
        byteCount: Int64
    ) -> ModelSource {
        ModelSource(
            provider: .huggingFace,
            repository: repository,
            revision: revision,
            homepageURL: URL(string: "https://huggingface.co/\(repository)"),
            artifacts: [
                ModelArtifact(
                    id: fileName,
                    url: URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(fileName)")!,
                    relativePath: fileName,
                    byteCount: byteCount
                )
            ]
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

    private static let baseGGUFLocalTags = [
        "downloadable",
        "gguf",
        "llama.cpp",
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

    private static let qwenChatTemplateArtifacts = [
        "chat_template.jinja",
        "config.json",
        "generation_config.json",
        "model.safetensors",
        "model.safetensors.index.json",
        "tokenizer.json",
        "tokenizer_config.json"
    ]

    private static let qwenOptiQArtifacts = [
        "chat_template.jinja",
        "config.json",
        "model.safetensors",
        "model.safetensors.index.json",
        "tokenizer.json",
        "tokenizer_config.json"
    ]

    private static let qwenInstructArtifacts = [
        "added_tokens.json",
        "chat_template.jinja",
        "config.json",
        "generation_config.json",
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

    private static let llamaTextArtifacts = [
        "config.json",
        "model.safetensors",
        "model.safetensors.index.json",
        "special_tokens_map.json",
        "tokenizer.json",
        "tokenizer_config.json"
    ]

    private static func llamaLicense(repository: String) -> ModelLicense {
        ModelLicense(
            name: "Llama Community License",
            url: URL(string: "https://huggingface.co/\(repository)/blob/main/LICENSE")
        )
    }
}
