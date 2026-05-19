import SwiftUI

struct LLMSettingsSectionVisual {
    let title: String
    let subtitle: String
    let detail: String
    let systemImage: String
    let tint: Color

    init(_ section: LLMSettingsSection) {
        switch section {
        case .overview:
            self.init(
                title: "Overview",
                subtitle: "Current model, effective limits, and recommendations",
                detail: "Effective values include user settings, selected model limits, and memory clamps.",
                systemImage: "sparkles",
                tint: .blue
            )
        case .modelAndRouting:
            self.init(
                title: "Model & Routing",
                subtitle: "Backend selection, quality profile, and privacy mode",
                detail: "Routing controls decide which backends can be considered. Privacy mode affects whether non-local execution is allowed.",
                systemImage: "point.3.connected.trianglepath.dotted",
                tint: .blue
            )
        case .contextAndOutput:
            self.init(
                title: "Context & Output",
                subtitle: "Input window, answer length, and model caps",
                detail: "Context is the input budget for prompts and recent chat history. Max output is the answer budget; higher values use more memory and time.",
                systemImage: "text.word.spacing",
                tint: .purple
            )
        case .prompt:
            self.init(
                title: "Prompt",
                subtitle: "Host-owned system prompt and behavior summary",
                detail: "System prompts define assistant behavior. Keep safety and domain constraints here instead of duplicating them in backend code.",
                systemImage: "text.alignleft",
                tint: .indigo
            )
        case .localMemory:
            self.init(
                title: "Local Memory",
                subtitle: "Free RAM floor and low-memory behavior",
                detail: "The RAM floor blocks local starts when memory is tight. Raise it for stability; lower it only for controlled experiments.",
                systemImage: "memorychip",
                tint: .orange
            )
        case .mlx:
            self.init(
                title: "MLX",
                subtitle: "Cache, KV window, quantization, and prefill",
                detail: "MLX cache and KV controls trade memory for speed. Quantized KV reduces memory; larger prefill steps may improve speed but can spike RAM.",
                systemImage: "bolt.horizontal",
                tint: .yellow
            )
        case .gguf:
            self.init(
                title: "GGUF",
                subtitle: "llama.cpp context, mmap, GPU, batch, and threads",
                detail: "GGUF context controls native llama.cpp memory. mmap lowers load pressure, Metal speeds supported devices, and experimental KV policies may fall back at runtime.",
                systemImage: "cpu",
                tint: .teal
            )
        case .safety:
            self.init(
                title: "Safety",
                subtitle: "Host-owned boundaries and fallback behavior",
                detail: "Safety settings should describe boundaries and failure behavior without leaking backend-specific implementation.",
                systemImage: "shield",
                tint: .red
            )
        case .storage:
            self.init(
                title: "Storage",
                subtitle: "Model files, catalog status, and saved sessions",
                detail: "Model files, partial downloads, and saved sessions affect disk use but stay separate from inference routing.",
                systemImage: "internaldrive",
                tint: .cyan
            )
        case .reset:
            self.init(
                title: "Reset",
                subtitle: "Presets, per-section resets, and recommended defaults",
                detail: "Use presets for broad tuning. Full reset restores the recommended defaults after confirmation.",
                systemImage: "arrow.counterclockwise",
                tint: .gray
            )
        }
    }

    private init(title: String, subtitle: String, detail: String, systemImage: String, tint: Color) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.systemImage = systemImage
        self.tint = tint
    }
}

struct LLMSettingsDetailHeader: View {
    let visual: LLMSettingsSectionVisual

    var body: some View {
        HStack(alignment: .top) {
            LLMSettingsChromeIcon(systemImage: visual.systemImage, tint: visual.tint)

            VStack(alignment: .leading) {
                Text(visual.title)
                    .font(.subheadline.weight(.semibold))

                Text(visual.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
