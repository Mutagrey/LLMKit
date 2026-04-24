import LLMCore
import LLMUIChat
import LLMUIDownloads
import SwiftUI

public struct LLMKitExampleScreen: View {
    @State private var viewModel: LLMKitExampleViewModel
    private let configuration: LLMKitExampleConfiguration

    public init(configuration: LLMKitExampleConfiguration = .localIPhoneCatalog()) {
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
                if let descriptor = viewModel.selectedModel, viewModel.canChatWithSelectedModel {
                    ChatScreen(
                        title: descriptor.displayName,
                        viewModel: ChatViewModel(
                            chatService: configuration.container.chat,
                            requirements: viewModel.chatRequirements
                        )
                    )
                    .id(viewModel.chatIdentity)
                } else if let descriptor = viewModel.selectedModel {
                    ContentUnavailableView(
                        "Model Not Ready",
                        systemImage: "arrow.down.circle",
                        description: Text("\(descriptor.displayName) is not ready for chat yet. Install it or switch to a ready model in the Models tab.")
                    )
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
                Section {
                    CatalogOverviewCard(
                        totalModels: viewModel.models.count,
                        readyModels: readyModels.count,
                        downloadableModels: configuration.downloadableModels.count,
                        installedModels: installedModels.count
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                if let selectedModel = viewModel.selectedModel {
                    Section("Selected Model") {
                        SelectedModelSummaryCard(
                            descriptor: selectedModel,
                            status: viewModel.statusText(for: selectedModel),
                            isAvailable: viewModel.isAvailable(selectedModel)
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }

                    if configuration.downloadableModels.contains(where: { $0.id == selectedModel.id }) {
                        Section("Install / Update") {
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
                }

                if !readyModels.isEmpty {
                    Section("Ready for Chat") {
                        ForEach(readyModels, id: \.id) { descriptor in
                            modelRowButton(for: descriptor)
                        }
                    }
                }

                if !downloadCandidates.isEmpty {
                    Section("Downloadable for iPhone") {
                        ForEach(downloadCandidates, id: \.id) { descriptor in
                            modelRowButton(for: descriptor)
                        }
                    }
                }

                if !configuration.downloadableModels.isEmpty {
                    Section("Download Catalog") {
                        NavigationLink {
                            ModelDownloadListView(
                                descriptors: configuration.downloadableModels,
                                lifecycleService: configuration.container.lifecycle
                            )
                            .navigationTitle("Downloads")
                        } label: {
                            Label(
                                "Browse All Downloadable Models",
                                systemImage: "square.stack.3d.down.right"
                            )
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

    private func modelRowButton(for descriptor: ModelDescriptor) -> some View {
        Button {
            viewModel.selectedModelID = descriptor.id
        } label: {
            ModelRow(
                descriptor: descriptor,
                status: viewModel.statusText(for: descriptor),
                isSystemManaged: viewModel.isSystemManaged(descriptor),
                isDownloadable: configuration.downloadableModels.contains(where: { $0.id == descriptor.id }),
                isSelected: descriptor.id == currentSelectedModelID,
                isAvailable: viewModel.isAvailable(descriptor)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var readyModels: [ModelDescriptor] {
        viewModel.models.filter { viewModel.isAvailable($0) }
    }

    private var installedModels: [ModelDescriptor] {
        configuration.downloadableModels.filter { downloadsViewModel.isInstalled($0.id) }
    }

    private var downloadCandidates: [ModelDescriptor] {
        configuration.downloadableModels.filter { !viewModel.isAvailable($0) }
    }

    private var currentSelectedModelID: ModelID? {
        viewModel.selectedModel?.id
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
                        LabeledContent("Backend", value: exampleBackendTitle(descriptor.backend))
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
                                isSelected: descriptor.id == currentSelectedModelID,
                                isAvailable: viewModel.isAvailable(descriptor)
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

#Preview {
    LLMKitExampleScreen(configuration: .localIPhoneCatalog())
}
