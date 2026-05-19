import LLMSettings
import SwiftUI

@MainActor
extension LLMSettingsDetailScreen {
    var mlxSections: some View {
        Group {
            Section {
                Stepper(value: $settings.mlxCacheLimitMB, in: mlxCacheRange, step: configuration.constraints.mlxCacheLimitMB.step) {
                    LabeledContent("MLX cache limit") {
                        Text(LLMSettingsFormatting.megabytes(settings.mlxCacheLimitMB))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Cache")
            } footer: {
                Text("Cache trades memory for speed.")
            }

            Section {
                Stepper(value: $settings.mlxMaxKVSizeTokens, in: mlxKVRange, step: configuration.constraints.mlxMaxKVSizeTokens.step) {
                    LabeledContent("KV cache window") {
                        Text(LLMSettingsFormatting.tokenCount(effective.mlxKVSizeTokens))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("KV quantization", selection: $settings.mlxKVBits) {
                    Text("Off").tag(0)
                    Text("4-bit").tag(4)
                    Text("8-bit").tag(8)
                }
                Stepper(value: $settings.mlxPrefillStepSize, in: mlxPrefillRange, step: configuration.constraints.mlxPrefillStepSize.step) {
                    LabeledContent("Prefill step") {
                        Text(LLMSettingsFormatting.tokenCount(settings.mlxPrefillStepSize))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("KV Cache")
            } footer: {
                Text("Quantized KV reduces memory. Larger prefill steps may improve speed but can spike RAM.")
            }

            Section {
                Toggle("Retain chat sessions", isOn: $settings.mlxRetainChatSessions)
                if configuration.showsAdvancedRuntimeControls {
                    Toggle("Clear cache after generation", isOn: $settings.mlxClearCacheAfterGeneration)
                    Toggle("Clear cache on unload", isOn: $settings.mlxClearCacheOnUnload)
                }
            } header: {
                Text("Runtime")
            }

            Section {
                Button("Reset MLX defaults") {
                    settings.resetMLX()
                }
            }
        }
    }
}
