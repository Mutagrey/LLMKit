import LLMCore
import LLMUIChat
import LLMUIDownloads
import SwiftUI

public struct LLMKitExampleScreen: View {
    @State private var viewModel: LLMKitExampleViewModel
    private let configuration: LLMKitExampleConfiguration

    public init(configuration: LLMKitExampleConfiguration = .appleIntelligenceOnly()) {
        self.configuration = configuration
        self._viewModel = State(initialValue: LLMKitExampleViewModel(configuration: configuration))
    }

    public var body: some View {
        TabView {
            ExampleChatTab(viewModel: viewModel, configuration: configuration)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            ExampleModelsTab(viewModel: viewModel, configuration: configuration)
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }

            ExampleSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            await viewModel.refresh()
        }
    }
}

private struct ExampleChatTab: View {
    let viewModel: LLMKitExampleViewModel
    let configuration: LLMKitExampleConfiguration

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ModelSelectionHeader(viewModel: viewModel)
                Divider()
                if let descriptor = viewModel.selectedModel {
                    ChatScreen(
                        title: descriptor.displayName,
                        viewModel: ChatViewModel(
                            chatService: configuration.container.chat,
                            requirements: viewModel.chatRequirements
                        )
                    )
                    .id(viewModel.chatIdentity)
                } else {
                    ContentUnavailableView(
                        "No Model",
                        systemImage: "cpu",
                        description: Text("Add a model descriptor to the example catalog.")
                    )
                }
            }
            .navigationTitle("Chat")
        }
    }
}

private struct ExampleModelsTab: View {
    let viewModel: LLMKitExampleViewModel
    let configuration: LLMKitExampleConfiguration

    var body: some View {
        NavigationStack {
            List(selection: selectedModelID) {
                Section("Available Models") {
                    ForEach(viewModel.models, id: \.id) { descriptor in
                        ModelRow(
                            descriptor: descriptor,
                            status: viewModel.statusText(for: descriptor),
                            isSystemManaged: viewModel.isSystemManaged(descriptor)
                        )
                        .tag(descriptor.id)
                    }
                }

                if !configuration.downloadableModels.isEmpty {
                    Section("Lifecycle") {
                        NavigationLink {
                            ModelDownloadListView(
                                descriptors: configuration.downloadableModels,
                                lifecycleService: configuration.container.lifecycle
                            )
                            .navigationTitle("Downloads")
                        } label: {
                            Label("Downloads", systemImage: "arrow.down.circle")
                        }
                    }
                }
            }
            .navigationTitle("Models")
            .overlay {
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityLabel("Refreshing models")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    private var selectedModelID: Binding<ModelID?> {
        Binding(
            get: { viewModel.selectedModelID },
            set: { viewModel.selectedModelID = $0 }
        )
    }
}

private struct ExampleSettingsTab: View {
    let viewModel: LLMKitExampleViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Generation") {
                    Picker("Quality", selection: qualityTier) {
                        ForEach(Self.qualityTiers, id: \.self) { tier in
                            Text(title(for: tier)).tag(tier)
                        }
                    }

                    Stepper(value: maxOutputTokens, in: 64...4096, step: 64) {
                        LabeledContent("Max Output Tokens", value: "\(viewModel.maxOutputTokens)")
                    }
                }

                Section("Routing") {
                    Picker("Execution", selection: executionMode) {
                        ForEach(Self.executionModes, id: \.self) { mode in
                            Text(title(for: mode)).tag(mode)
                        }
                    }

                    Picker("Privacy", selection: privacyMode) {
                        ForEach(Self.privacyModes, id: \.self) { mode in
                            Text(title(for: mode)).tag(mode)
                        }
                    }
                }

                Section("Selected Model") {
                    if let descriptor = viewModel.selectedModel {
                        LabeledContent("Name", value: descriptor.displayName)
                        LabeledContent("Backend", value: backendTitle(for: descriptor.backend))
                        LabeledContent("Status", value: viewModel.statusText(for: descriptor))
                    } else {
                        Text("No model selected")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private static let executionModes: [ExecutionMode] = [
        .offlineOnly,
        .preferOffline,
        .hybrid,
        .remoteAllowed
    ]

    private static let qualityTiers: [QualityTier] = [
        .fast,
        .balanced,
        .best
    ]

    private static let privacyModes: [PrivacyMode] = [
        .standard,
        .localOnly,
        .redactSensitive
    ]

    private var executionMode: Binding<ExecutionMode> {
        Binding(
            get: { viewModel.executionMode },
            set: { viewModel.executionMode = $0 }
        )
    }

    private var qualityTier: Binding<QualityTier> {
        Binding(
            get: { viewModel.qualityTier },
            set: { viewModel.qualityTier = $0 }
        )
    }

    private var privacyMode: Binding<PrivacyMode> {
        Binding(
            get: { viewModel.privacyMode },
            set: { viewModel.privacyMode = $0 }
        )
    }

    private var maxOutputTokens: Binding<Int> {
        Binding(
            get: { viewModel.maxOutputTokens },
            set: { viewModel.maxOutputTokens = $0 }
        )
    }

    private func title(for mode: ExecutionMode) -> String {
        switch mode {
        case .offlineOnly:
            return "Offline Only"
        case .preferOffline:
            return "Prefer Offline"
        case .hybrid:
            return "Hybrid"
        case .remoteAllowed:
            return "Remote Allowed"
        }
    }

    private func title(for tier: QualityTier) -> String {
        switch tier {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced"
        case .best:
            return "Best"
        }
    }

    private func title(for mode: PrivacyMode) -> String {
        switch mode {
        case .standard:
            return "Standard"
        case .localOnly:
            return "Local Only"
        case .redactSensitive:
            return "Redact Sensitive"
        }
    }

    private func backendTitle(for backend: BackendKind) -> String {
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
}

private struct ModelSelectionHeader: View {
    let viewModel: LLMKitExampleViewModel

    var body: some View {
        Picker("Model", selection: selectedModelID) {
            ForEach(viewModel.models, id: \.id) { descriptor in
                Text(descriptor.displayName).tag(Optional(descriptor.id))
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .disabled(viewModel.models.isEmpty)
    }

    private var selectedModelID: Binding<ModelID?> {
        Binding(
            get: { viewModel.selectedModelID },
            set: { viewModel.selectedModelID = $0 }
        )
    }
}

private struct ModelRow: View {
    let descriptor: ModelDescriptor
    let status: String
    let isSystemManaged: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSystemManaged ? "apple.intelligence" : "cpu")
                .frame(width: 22)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.displayName)
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isSystemManaged {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("System managed")
            }
        }
        .padding(.vertical, 3)
    }
}

#Preview {
    LLMKitExampleScreen()
}
