import LLMCore
import LLMSettings
import SwiftUI

@MainActor
extension LLMSettingsDetailScreen {
    var ggufSections: some View {
        Group {
            ggufContextSection
            ggufLoadingSection
            ggufGPUSection
            ggufPerformanceSection
            Section {
                Button("Reset GGUF defaults") {
                    settings.resetGGUF()
                }
            }
        }
    }

    private var ggufContextSection: some View {
        Section {
            Toggle("Follow context window", isOn: $settings.ggufContextFollowsRequest)
            if !settings.ggufContextFollowsRequest {
                Stepper(value: $settings.ggufContextWindowTokens, in: contextRange, step: configuration.constraints.contextWindowTokens.step) {
                    LabeledContent("GGUF context") {
                        Text(LLMSettingsFormatting.tokenCount(effective.ggufContextSizeTokens))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Context")
        } footer: {
            Text("GGUF context controls native llama.cpp memory.")
        }
    }

    private var ggufLoadingSection: some View {
        Section {
            Toggle("Use mmap", isOn: $settings.ggufUseMMap)
        } header: {
            Text("Loading")
        } footer: {
            Text("mmap lowers load pressure when supported.")
        }
    }

    private var ggufGPUSection: some View {
        Section {
            Picker("GPU offload", selection: $settings.ggufGPUOffloadPolicy) {
                Text("Automatic").tag(LLMGPUOffloadPolicy.automatic)
                Text("Off").tag(LLMGPUOffloadPolicy.disabled)
                Text("Custom").tag(LLMGPUOffloadPolicy.custom(layerCount: settings.ggufGPUOffloadPolicy.requestedLayerCount))
            }
            if case .custom = settings.ggufGPUOffloadPolicy {
                Stepper(value: ggufCustomGPULayers, in: ggufGPULayerRange, step: configuration.constraints.ggufCustomGPULayers.step) {
                    LabeledContent("GPU layers") {
                        Text("\(settings.ggufGPUOffloadPolicy.requestedLayerCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("GPU")
        } footer: {
            Text("Changing GPU offload can require unloading active GGUF contexts.")
        }
    }

    private var ggufPerformanceSection: some View {
        Section {
            Picker("KV cache", selection: $settings.ggufKVCachePolicy) {
                Text("Runtime Default").tag(KVCachePolicy.runtimeDefault)
                Text("Safe F16").tag(KVCachePolicy.safeF16)
                Text("Q8 Experimental").tag(KVCachePolicy.q8Experimental)
                Text("Q4 Experimental").tag(KVCachePolicy.q4Experimental)
            }
            Stepper(value: $settings.ggufBatchSize, in: ggufBatchRange, step: configuration.constraints.ggufBatchSize.step) {
                LabeledContent("Batch size") {
                    Text("\(settings.ggufBatchSize)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Toggle("Automatic threads", isOn: ggufAutomaticThreads)
            if settings.ggufThreadCount != nil {
                Stepper(value: ggufThreadCount, in: ggufThreadRange, step: configuration.constraints.ggufThreadCount.step) {
                    LabeledContent("Threads") {
                        Text("\(settings.ggufThreadCount ?? 0)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("KV & Performance")
        } footer: {
            Text("Experimental KV policies may fall back at runtime.")
        }
    }
}
