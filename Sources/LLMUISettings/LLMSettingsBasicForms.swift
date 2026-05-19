import LLMCore
import LLMSettings
import SwiftUI

@MainActor
extension LLMSettingsDetailScreen {
    var routingSections: some View {
        Group {
            if let openModelSettings = actions.openModelSettings {
                Section {
                    Button {
                        openModelSettings()
                    } label: {
                        Label("Choose or manage models", systemImage: "cpu")
                    }
                }
            }

            Section {
                if configuration.allowsRoutingControls {
                    routingPickers
                } else {
                    LabeledContent("Execution", value: LLMSettingsFormatting.title(for: settings.executionMode))
                    LabeledContent("Privacy", value: LLMSettingsFormatting.title(for: settings.privacyMode))
                }
            } header: {
                Text("Routing")
            } footer: {
                Text(configuration.allowsRoutingControls ? "Controls which backends can be considered. Privacy mode limits whether non-local execution can be used." : "This profile is controlled by the host app and kept local/offline.")
            }

            Section {
                Button("Reset routing defaults") {
                    settings.resetRouting()
                }
            }
        }
    }

    var contextOutputSections: some View {
        Group {
            Section {
                tokenStepper(
                    "Context window",
                    value: $settings.contextWindowTokens,
                    displayValue: effective.inputTokens,
                    range: contextRange,
                    step: configuration.constraints.contextWindowTokens.step
                )
            } header: {
                Text("Context")
            } footer: {
                Text("Raises or lowers the prompt and recent-history budget. Larger windows use more memory.")
            }

            Section {
                tokenStepper(
                    "Max output",
                    value: $settings.maxOutputTokens,
                    displayValue: effective.outputTokens,
                    range: outputRange,
                    step: configuration.constraints.outputTokens.step
                )
            } header: {
                Text("Output")
            } footer: {
                Text("Caps answer length. Higher values can improve long responses but increase latency.")
            }

            Section {
                Button("Reset token defaults") {
                    settings.resetGeneration()
                }
            }
        }
    }

    var promptSections: some View {
        Group {
            Section {
                Text(context.promptSummary ?? "Prompt content is owned by the host app.")
                    .foregroundStyle(.secondary)
            }

            if let resetPrompt = actions.resetPrompt {
                Section {
                    Button("Reset prompt default") {
                        resetPrompt()
                    }
                }
            }
        }
    }

    var localMemorySections: some View {
        Group {
            Section {
                Stepper(
                    value: $settings.criticalFreeRAMFloorMB,
                    in: localMemoryRange,
                    step: configuration.constraints.criticalFreeRAMFloorMB.step
                ) {
                    LabeledContent("Free RAM floor") {
                        Text(LLMSettingsFormatting.megabytes(settings.criticalFreeRAMFloorMB))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Memory Guard")
            } footer: {
                Text("Blocks local starts when free memory drops below this value. Raise it for stability.")
            }

            Section {
                Button("Reset memory defaults") {
                    settings.resetMemory()
                }
            }
        }
    }

    var safetySections: some View {
        Section {
            Text(context.safetySummary ?? "Safety policy is owned by the host app.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var routingPickers: some View {
        Picker("Execution", selection: $settings.executionMode) {
            ForEach(executionModes, id: \.self) { mode in
                Text(LLMSettingsFormatting.title(for: mode)).tag(mode)
            }
        }
        Picker("Quality", selection: $settings.qualityTier) {
            ForEach(Self.qualityTiers, id: \.self) { tier in
                Text(LLMSettingsFormatting.title(for: tier)).tag(tier)
            }
        }
        Picker("Privacy", selection: $settings.privacyMode) {
            ForEach(Self.privacyModes, id: \.self) { mode in
                Text(LLMSettingsFormatting.title(for: mode)).tag(mode)
            }
        }
    }

    private func tokenStepper(
        _ title: String,
        value: Binding<Int>,
        displayValue: Int,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            LabeledContent(title) {
                Text(LLMSettingsFormatting.tokenCount(displayValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
