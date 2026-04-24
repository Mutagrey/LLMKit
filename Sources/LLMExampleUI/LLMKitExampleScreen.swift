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
            Group {
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
                        description: Text("\(descriptor.displayName) is not ready for chat yet. Install it or switch to a ready model from the toolbar or the Models tab.")
                    )
                } else {
                    ContentUnavailableView(
                        "No Model",
                        systemImage: "cpu",
                        description: Text("Add a model descriptor to the example catalog.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ChatModelToolbarMenu(
                        models: viewModel.models,
                        selectedModel: viewModel.selectedModel,
                        statusText: viewModel.selectedModel.map(viewModel.statusText(for:)) ?? "No model selected",
                        isRefreshing: viewModel.isRefreshing
                    ) { descriptor in
                        viewModel.selectedModelID = descriptor.id
                    }
                }

                if viewModel.isRefreshing {
                    ToolbarItem {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing models")
                    }
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
            initialValue: ModelDownloadsViewModel(
                descriptors: configuration.downloadableModels,
                lifecycleService: configuration.container.lifecycle
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CatalogOverviewCard(
                        totalModels: viewModel.models.count,
                        readyModels: readyModels.count,
                        downloadableModels: viewModel.downloadableModels.count,
                        installedModels: installedModels.count,
                        installedSize: downloadsViewModel.installedStorageTitle,
                        catalogStatus: viewModel.catalogStatus
                    )
                }

                if let selectedModel = viewModel.selectedModel {
                    Section("Current") {
                        NavigationLink {
                            ModelDetailView(
                                descriptor: selectedModel,
                                status: viewModel.statusText(for: selectedModel),
                                isAvailable: viewModel.isAvailable(selectedModel)
                            )
                            .navigationTitle(selectedModel.displayName)
                        } label: {
                            CurrentModelSummaryRow(
                                descriptor: selectedModel,
                                status: viewModel.statusText(for: selectedModel),
                                isAvailable: viewModel.isAvailable(selectedModel)
                            )
                        }
                    }

                    if viewModel.downloadableModels.contains(where: { $0.id == selectedModel.id }) {
                        Section("Install") {
                            ModelDownloadCardView(
                                descriptor: selectedModel,
                                state: downloadsViewModel.installState(for: selectedModel.id),
                                installedSizeBytes: downloadsViewModel.storageBytes(for: selectedModel.id),
                                isInstallButtonDisabled: downloadsViewModel.isInstallButtonDisabled(for: selectedModel.id)
                            ) {
                                await downloadsViewModel.install(selectedModel)
                                await viewModel.refresh()
                            } deleteAction: {
                                await downloadsViewModel.delete(selectedModel.id)
                                await viewModel.refresh()
                            }
                        }
                    }
                }

                if !readyModels.isEmpty {
                    Section("Ready for Chat") {
                        ForEach(readyModels, id: \.id) { descriptor in
                            modelSelectionRow(for: descriptor)
                        }
                    }
                }

                if !downloadCandidates.isEmpty {
                    Section("Downloadable for iPhone") {
                        ForEach(downloadCandidates, id: \.id) { descriptor in
                            modelSelectionRow(for: descriptor)
                        }
                    }
                }

                if !viewModel.downloadableModels.isEmpty {
                    Section("Download Catalog") {
                        NavigationLink {
                            ModelDownloadListView(
                                descriptors: viewModel.downloadableModels,
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
                downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
                await downloadsViewModel.refresh()
            }
            .task {
                downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
                await downloadsViewModel.refresh()
            }
            .task(id: trackedDownloadablesKey) {
                downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
            }
        }
    }

    private func modelSelectionRow(for descriptor: ModelDescriptor) -> some View {
        HStack(spacing: 8) {
            Button {
                viewModel.selectedModelID = descriptor.id
            } label: {
                ModelRow(
                    descriptor: descriptor,
                    status: viewModel.statusText(for: descriptor),
                    isSelected: descriptor.id == currentSelectedModelID,
                    isAvailable: viewModel.isAvailable(descriptor)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ModelDetailView(
                    descriptor: descriptor,
                    status: viewModel.statusText(for: descriptor),
                    isAvailable: viewModel.isAvailable(descriptor)
                )
                .navigationTitle(descriptor.displayName)
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Model details")
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }

    private var readyModels: [ModelDescriptor] {
        viewModel.models.filter { viewModel.isAvailable($0) }
    }

    private var installedModels: [ModelDescriptor] {
        viewModel.downloadableModels.filter { downloadsViewModel.isInstalled($0.id) }
    }

    private var downloadCandidates: [ModelDescriptor] {
        viewModel.downloadableModels.filter { !viewModel.isAvailable($0) }
    }

    private var currentSelectedModelID: ModelID? {
        viewModel.selectedModel?.id
    }

    private var trackedDownloadablesKey: String {
        viewModel.downloadableModels.map { $0.id.rawValue }.joined(separator: "|")
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

                Section("Catalog") {
                    LabeledContent("Source", value: catalogSourceTitle)
                    if let catalogMessage {
                        Text(catalogMessage)
                            .font(.caption)
                            .foregroundStyle(viewModel.catalogStatus.source == .fallback ? .orange : .secondary)
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

    private var catalogSourceTitle: String {
        switch viewModel.catalogStatus.source {
        case .local:
            return "Local"
        case .remoteVerified:
            return "Signed Remote"
        case .fallback:
            return "Fallback"
        }
    }

    private var catalogMessage: String? {
        guard let message = viewModel.catalogStatus.message, !message.isEmpty else {
            return nil
        }
        return message
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

#Preview {
    LLMKitExampleScreen(configuration: .localIPhoneCatalog())
}
