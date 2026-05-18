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
                LabeledContent("Backend", value: demoBackendTitle(descriptor.backend))
                LabeledContent("Family", value: descriptor.family.title)
                LabeledContent("Model ID", value: descriptor.id.rawValue)
            }

            Section("Requirements") {
                LabeledContent("Download", value: demoByteCountTitle(descriptor.estimatedDownloadSizeBytes))
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
                    ForEach(demoCapabilityTitles(for: descriptor), id: \.self) { capability in
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
