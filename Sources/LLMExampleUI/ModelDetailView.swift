import Foundation
import LLMCore
import SwiftUI

struct ModelDetailView: View {
    let descriptor: ModelDescriptor
    let status: String
    let isAvailable: Bool

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Status", value: isAvailable ? "Ready" : status)
                LabeledContent("Backend", value: exampleBackendTitle(descriptor.backend))
                LabeledContent("Family", value: exampleModelFamilyTitle(descriptor.family))
                LabeledContent("Model ID", value: descriptor.id.rawValue)
            }

            Section("Requirements") {
                LabeledContent("Download", value: exampleByteCountTitle(descriptor.estimatedDownloadSizeBytes))
                if let minimumRAMGB = descriptor.minimumRAMGB {
                    LabeledContent("Memory", value: "\(minimumRAMGB) GB RAM")
                }
                if let minimumFreeDiskGB = descriptor.minimumFreeDiskGB {
                    LabeledContent("Free Disk", value: "\(minimumFreeDiskGB) GB")
                }
                if let contextWindowTokens = descriptor.contextWindowTokens {
                    LabeledContent("Context", value: "\(contextWindowTokens) tokens")
                }
                if let quantization = descriptor.quantization?.format {
                    LabeledContent("Quantization", value: quantization)
                }
            }

            if !descriptor.capabilities.isEmpty {
                Section("Capabilities") {
                    ForEach(exampleCapabilityTitles(for: descriptor), id: \.self) { capability in
                        Text(capability)
                    }
                }
            }

            Section("Source") {
                LabeledContent("Provider", value: sourceProviderTitle)
                if let repository = descriptor.source?.repository {
                    LabeledContent("Repository", value: repository)
                }
                if let revision = descriptor.source?.revision {
                    LabeledContent("Revision", value: String(revision.prefix(12)))
                }
                LabeledContent("License", value: descriptor.license?.spdxIdentifier ?? descriptor.license?.name ?? "Unspecified")
            }
        }
    }

    private var sourceProviderTitle: String {
        guard let provider = descriptor.source?.provider else {
            return "Unknown"
        }

        switch provider {
        case .huggingFace:
            return "Hugging Face"
        case .remoteURL:
            return "Remote URL"
        case .bundled:
            return "Bundled"
        case .custom(let value):
            return value
        }
    }
}

func exampleBackendTitle(_ backend: BackendKind) -> String {
    switch backend {
    case .foundationModels:
        return "Foundation Models"
    case .coreML:
        return "Core ML"
    case .mlx:
        return "MLX"
    case .remote:
        return "Remote"
    case .executorch:
        return "ExecuTorch"
    case .onnxRuntime:
        return "ONNX Runtime"
    case .custom(let name):
        return name
    }
}

func exampleModelFamilyTitle(_ family: ModelFamily) -> String {
    switch family {
    case .appleFoundation:
        return "Apple Foundation"
    case .qwen:
        return "Qwen"
    case .gemma:
        return "Gemma"
    case .llama:
        return "Llama"
    case .mistral:
        return "Mistral"
    case .custom(let value):
        return value
    }
}

func exampleByteCountTitle(_ bytes: Int64?) -> String {
    guard let bytes else {
        return "Unknown size"
    }
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

func exampleCapabilityTitles(for descriptor: ModelDescriptor) -> [String] {
    let preferredOrder: [ModelCapability] = [
        .chat,
        .completion,
        .streaming,
        .structuredOutput,
        .offline,
        .lowLatency,
        .toolCalling,
        .summarization,
        .classification,
        .longContext,
        .multimodalInput
    ]

    let labels: [ModelCapability: String] = [
        .chat: "Chat",
        .completion: "Completion",
        .streaming: "Streaming",
        .structuredOutput: "Structured",
        .offline: "Offline",
        .lowLatency: "Low Latency",
        .toolCalling: "Tools",
        .summarization: "Summaries",
        .classification: "Classification",
        .longContext: "Long Context",
        .multimodalInput: "Multimodal"
    ]

    return preferredOrder.compactMap { capability in
        guard descriptor.capabilities.contains(capability) else {
            return nil
        }
        return labels[capability]
    }
}
