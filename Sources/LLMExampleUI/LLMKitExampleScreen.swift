import LLMCore
import LLMUIChat
import LLMUIDownloads
import SwiftUI

public struct LLMKitExampleScreen: View {
    @State private var viewModel: LLMKitExampleViewModel
    private let configuration: LLMKitExampleConfiguration

    public init(configuration: LLMKitExampleConfiguration = .localQwenSmokeTest()) {
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
    @State private var downloadsViewModel: ModelDownloadsViewModel

    init(viewModel: LLMKitExampleViewModel, configuration: LLMKitExampleConfiguration) {
        self.viewModel = viewModel
        self.configuration = configuration
        self._downloadsViewModel = State(
            initialValue: ModelDownloadsViewModel(lifecycleService: configuration.container.lifecycle)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Available Models") {
                    ForEach(viewModel.models, id: \.id) { descriptor in
                        Button {
                            viewModel.selectedModelID = descriptor.id
                        } label: {
                            ModelRow(
                                descriptor: descriptor,
                                status: viewModel.statusText(for: descriptor),
                                isSystemManaged: viewModel.isSystemManaged(descriptor),
                                isDownloadable: configuration.downloadableModels.contains(where: { $0.id == descriptor.id }),
                                isSelected: descriptor.id == currentSelectedModelID
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                if let selectedModel = viewModel.selectedModel {
                    Section("Selected Model") {
                        SelectedModelSummary(
                            descriptor: selectedModel,
                            status: viewModel.statusText(for: selectedModel)
                        )
                    }

                    if configuration.downloadableModels.contains(where: { $0.id == selectedModel.id }) {
                        Section("Download") {
                            ModelDownloadCardView(
                                descriptor: selectedModel,
                                state: downloadsViewModel.installState(for: selectedModel.id),
                                isInstallButtonDisabled: downloadsViewModel.isInstallButtonDisabled(for: selectedModel.id)
                            ) {
                                await downloadsViewModel.install(selectedModel)
                                await viewModel.refresh()
                            }
                        }
                    }

                    if !configuration.downloadableModels.isEmpty {
                        Section("Catalog") {
                            NavigationLink {
                                ModelDownloadListView(
                                    descriptors: configuration.downloadableModels,
                                    lifecycleService: configuration.container.lifecycle
                                )
                                .navigationTitle("Downloads")
                            } label: {
                                Label("All Downloadable Models", systemImage: "square.stack.3d.down.right")
                            }
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
                await downloadsViewModel.refresh()
            }
            .task {
                await downloadsViewModel.refresh()
            }
        }
    }

    private var currentSelectedModelID: ModelID? {
        viewModel.selectedModel?.id
    }
}

private struct SelectedModelSummary: View {
    let descriptor: ModelDescriptor
    let status: String

    var body: some View {
        LabeledContent("Name", value: descriptor.displayName)
        LabeledContent("Backend", value: backendTitle)
        LabeledContent("Status", value: status)

        if let quantization = descriptor.quantization?.format {
            LabeledContent("Quantization", value: quantization)
        }

        if let contextWindowTokens = descriptor.contextWindowTokens {
            LabeledContent("Context", value: "\(contextWindowTokens) tokens")
        }

        if let estimatedDownloadSizeBytes = descriptor.estimatedDownloadSizeBytes {
            LabeledContent(
                "Download",
                value: ByteCountFormatter.string(fromByteCount: estimatedDownloadSizeBytes, countStyle: .file)
            )
        }

        if let repository = descriptor.source?.repository {
            LabeledContent("Source", value: repository)
        }
    }

    private var backendTitle: String {
        switch descriptor.backend {
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
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.models, id: \.id) { descriptor in
                        Button {
                            viewModel.selectedModelID = descriptor.id
                        } label: {
                            ModelSelectionChip(
                                descriptor: descriptor,
                                isSelected: descriptor.id == currentSelectedModelID
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            Divider()
        }
        .background(Color.primary.opacity(0.04))
    }

    private var currentSelectedModelID: ModelID? {
        viewModel.selectedModel?.id
    }
}

private struct ModelSelectionChip: View {
    let descriptor: ModelDescriptor
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: descriptor.backend == .foundationModels ? "apple.intelligence" : "cpu")
                    .font(.caption.weight(.semibold))
                Text(descriptor.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.primary.opacity(0.9) : Color.secondary)
                .lineLimit(1)
        }
        .frame(width: 220, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
        }
    }

    private var subtitle: String {
        switch descriptor.backend {
        case .foundationModels:
            return "System model"
        case .mlx:
            return "Local MLX"
        case .coreML:
            return "Local Core ML"
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

    private var backgroundStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.tint.opacity(0.16))
        }
        return AnyShapeStyle(Color.primary.opacity(0.03))
    }

    private var borderColor: Color {
        isSelected ? .accentColor : .secondary.opacity(0.2)
    }
}

private struct ModelRow: View {
    let descriptor: ModelDescriptor
    let status: String
    let isSystemManaged: Bool
    let isDownloadable: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSystemManaged ? "apple.intelligence" : "cpu")
                .font(.headline)
                .frame(width: 30, height: 30)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(descriptor.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if isDownloadable {
                        ModelPill(title: "Download", tint: .blue)
                    } else if isSystemManaged {
                        ModelPill(title: "System", tint: .secondary)
                    }
                }

                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.headline)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                .accessibilityLabel(isSelected ? "Selected" : "Not selected")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(rowBorder, lineWidth: isSelected ? 1.5 : 1)
        }
    }

    private var rowBackground: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.tint.opacity(0.12))
        }
        return AnyShapeStyle(Color.primary.opacity(0.05))
    }

    private var iconBackground: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.tint.opacity(0.12))
        }
        return AnyShapeStyle(Color.primary.opacity(0.03))
    }

    private var rowBorder: Color {
        isSelected ? .accentColor : .secondary.opacity(0.2)
    }
}

private struct ModelPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule(style: .continuous))
    }
}

#Preview {
    LLMKitExampleScreen(configuration: .localQwenSmokeTest())
}
