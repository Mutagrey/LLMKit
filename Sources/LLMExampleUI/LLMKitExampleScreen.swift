import LLMCore
import LLMUIChat
import LLMUIDownloads
import SwiftUI

public struct LLMKitExampleScreen: View {
    @State private var viewModel: LLMKitExampleViewModel
    @State private var downloadsViewModel: ModelDownloadsViewModel
    private let configuration: LLMKitExampleConfiguration

    public init(configuration: LLMKitExampleConfiguration = .localIPhoneCatalog()) {
        self.configuration = configuration
        self._viewModel = State(initialValue: LLMKitExampleViewModel(configuration: configuration))
        self._downloadsViewModel = State(
            initialValue: ModelDownloadsViewModel(
                descriptors: configuration.downloadableModels,
                lifecycleService: configuration.container.lifecycle
            )
        )
    }

    public var body: some View {
        TabView {
            ExampleSessionChatTab(
                viewModel: viewModel,
                configuration: configuration
            )
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            ExampleModelsTab(
                viewModel: viewModel,
                downloadsViewModel: downloadsViewModel
            )
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }

            ExampleSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            await refreshAll()
        }
    }

    private func refreshAll() async {
        await viewModel.refresh()
        downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
        await downloadsViewModel.refresh()
    }
}

private struct ExampleChatTab: View {
    let viewModel: LLMKitExampleViewModel
    let downloadsViewModel: ModelDownloadsViewModel
    let configuration: LLMKitExampleConfiguration

    private var presentation: ExampleModelPresentation {
        ExampleModelPresentation(
            viewModel: viewModel,
            downloadsViewModel: downloadsViewModel
        )
    }

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
                        selectedStatusText: viewModel.selectedModel.map(presentation.statusText(for:)) ?? "No model selected",
                        isRefreshing: viewModel.isRefreshing
                    ) { descriptor in
                        viewModel.selectedModelID = descriptor.id
                    } statusText: { descriptor in
                        presentation.statusText(for: descriptor)
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
    let downloadsViewModel: ModelDownloadsViewModel
    @State private var presentedDetail: PresentedModelDetail?

    private var presentation: ExampleModelPresentation {
        ExampleModelPresentation(
            viewModel: viewModel,
            downloadsViewModel: downloadsViewModel
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CatalogOverviewCard(
                        totalModels: viewModel.models.count,
                        readyModels: readyModelCount,
                        downloadableModels: viewModel.downloadableModels.count,
                        installedModels: installedModelCount,
                        installedSize: downloadsViewModel.installedStorageTitle,
                        catalogStatus: viewModel.catalogStatus
                    )
                }

                Section("Model Catalog") {
                    ForEach(catalogModels, id: \.id) { descriptor in
                        modelCard(for: descriptor)
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
            .safeAreaInset(edge: .bottom) {
                if let errorMessage = downloadsViewModel.lastErrorMessage ?? viewModel.lastErrorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background)
                }
            }
            .refreshable {
                await refreshAll()
            }
            .task(id: trackedDownloadablesKey) {
                downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
            }
            .task(id: installLifecycleKey) {
                guard !viewModel.downloadableModels.isEmpty else {
                    return
                }
                await viewModel.refresh()
            }
            .sheet(item: $presentedDetail) { detail in
                NavigationStack {
                    ModelDetailView(
                        descriptor: detail.descriptor,
                        status: presentation.statusText(for: detail.descriptor),
                        isAvailable: presentation.isReadyForChat(detail.descriptor)
                    )
                    .navigationTitle(detail.descriptor.displayName)
                }
            }
        }
    }

    private func modelCard(for descriptor: ModelDescriptor) -> some View {
        ExampleModelCard(
            descriptor: descriptor,
            status: presentation.statusText(for: descriptor),
            isAvailable: presentation.isReadyForChat(descriptor),
            installState: presentation.installState(for: descriptor),
            installedSizeBytes: downloadsViewModel.storageBytes(for: descriptor.id),
            isInstallButtonDisabled: downloadsViewModel.isInstallButtonDisabled(for: descriptor.id),
            installAction: installAction(for: descriptor),
            cancelAction: cancelAction(for: descriptor)
        ) {
            presentedDetail = PresentedModelDetail(descriptor: descriptor)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if downloadsViewModel.isInstalled(descriptor.id) {
                Button(role: .destructive) {
                    Task {
                        await downloadsViewModel.delete(descriptor.id)
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    private var catalogModels: [ModelDescriptor] {
        viewModel.models.sorted { lhs, rhs in
            let lhsPriority = presentation.modelPriority(for: lhs)
            let rhsPriority = presentation.modelPriority(for: rhs)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.displayName < rhs.displayName
        }
    }

    private var readyModelCount: Int {
        viewModel.models.filter(presentation.isReadyForChat).count
    }

    private var installedModelCount: Int {
        viewModel.downloadableModels.filter { downloadsViewModel.isInstalled($0.id) }.count
    }

    private var trackedDownloadablesKey: String {
        viewModel.downloadableModels.map { $0.id.rawValue }.joined(separator: "|")
    }

    private var installLifecycleKey: String {
        viewModel.downloadableModels
            .map { descriptor in
                "\(descriptor.id.rawValue):\(installLifecyclePhase(for: descriptor.id))"
            }
            .joined(separator: "|")
    }

    private func installAction(for descriptor: ModelDescriptor) -> (() async -> Void)? {
        guard presentation.installState(for: descriptor) != nil else {
            return nil
        }
        return {
            await downloadsViewModel.beginInstall(descriptor)
        }
    }

    private func cancelAction(for descriptor: ModelDescriptor) -> (() async -> Void)? {
        guard downloadsViewModel.isInstalling(descriptor.id) else {
            return nil
        }
        return {
            await downloadsViewModel.cancelInstall(descriptor.id)
            await viewModel.refresh()
        }
    }

    private func installLifecyclePhase(for modelID: ModelID) -> String {
        switch downloadsViewModel.installState(for: modelID) {
        case .notInstalled:
            return "notInstalled"
        case .downloading:
            return "downloading"
        case .downloaded:
            return "downloaded"
        case .verifying:
            return "verifying"
        case .compiling:
            return "compiling"
        case .ready:
            return "ready"
        case .warming:
            return "warming"
        case .active:
            return "active"
        case .failed:
            return "failed"
        case .evicted:
            return "evicted"
        }
    }

    private func refreshAll() async {
        await viewModel.refresh()
        await refreshDownloads()
    }

    private func refreshDownloads() async {
        downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
        await downloadsViewModel.refresh()
    }
}

private struct PresentedModelDetail: Identifiable {
    let descriptor: ModelDescriptor

    var id: ModelID {
        descriptor.id
    }
}

@MainActor
private struct ExampleModelPresentation {
    let viewModel: LLMKitExampleViewModel
    let downloadsViewModel: ModelDownloadsViewModel

    func installState(for descriptor: ModelDescriptor) -> InstallState? {
        guard viewModel.downloadableModels.contains(where: { $0.id == descriptor.id }) else {
            return nil
        }
        return downloadsViewModel.installState(for: descriptor.id)
    }

    func statusText(for descriptor: ModelDescriptor) -> String {
        if installState(for: descriptor) != nil {
            return downloadsViewModel.statusText(for: descriptor.id)
        }
        return viewModel.statusText(for: descriptor)
    }

    func isReadyForChat(_ descriptor: ModelDescriptor) -> Bool {
        if let installState = installState(for: descriptor) {
            switch installState {
            case .ready, .warming, .active:
                return true
            case .notInstalled, .downloading, .downloaded, .verifying, .compiling, .failed, .evicted:
                return viewModel.isAvailable(descriptor)
            }
        }
        return viewModel.isAvailable(descriptor)
    }

    func modelPriority(for descriptor: ModelDescriptor) -> Int {
        if isReadyForChat(descriptor) {
            return 0
        }
        if downloadsViewModel.isInstalling(descriptor.id) {
            return 1
        }
        if downloadsViewModel.isInstalled(descriptor.id) {
            return 2
        }
        return 3
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
