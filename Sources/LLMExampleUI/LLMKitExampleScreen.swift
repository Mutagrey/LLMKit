import LLMCore
import LLMUIChat
import LLMUIDownloads
import SwiftUI

public struct LLMKitExampleScreen: View {
    @State private var viewModel: LLMKitExampleViewModel
    @State private var downloadsViewModel: ModelDownloadsViewModel
    @State private var selectedTab: ExampleDemoTab = .chat
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
        TabView(selection: $selectedTab) {
            ExampleSessionChatTab(
                viewModel: viewModel,
                configuration: configuration,
                openModels: {
                    selectedTab = .models
                }
            )
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(ExampleDemoTab.chat)

            ExampleModelsTab(
                viewModel: viewModel,
                downloadsViewModel: downloadsViewModel
            )
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
                .tag(ExampleDemoTab.models)

            ExampleSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(ExampleDemoTab.settings)
        }
        .tint(.blue)
        .exampleHiddenSystemTabBar()
        .background(ExampleDemoBackground().ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            if let summary = activeDownloadSummary {
                ActiveDownloadBanner(summary: summary)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ExampleDemoTabBar(selection: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .task {
            await refreshAll()
        }
    }

    private var activeDownloadSummary: ActiveDownloadSummary? {
        let activeIDs = downloadsViewModel.installingModelIDs.sorted { $0.rawValue < $1.rawValue }
        guard let modelID = activeIDs.first,
              downloadsViewModel.isInstalling(modelID) else {
            return nil
        }
        let descriptor = viewModel.model(for: modelID)
            ?? downloadsViewModel.models.first { $0.descriptor.id == modelID }?.descriptor
        let state = downloadsViewModel.installState(for: modelID)
        return ActiveDownloadSummary(
            title: activeDownloadTitle(for: state, descriptor: descriptor),
            detail: activeDownloadDetail(
                state: state,
                detail: downloadsViewModel.progressDetail(for: modelID),
                estimatedTotalBytes: descriptor?.estimatedDownloadSizeBytes
            ),
            progress: activeDownloadProgress(for: state),
            remainingCount: max(0, activeIDs.count - 1)
        )
    }

    private func refreshAll() async {
        await viewModel.refresh()
        downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
        await downloadsViewModel.refresh()
    }

    private func activeDownloadTitle(for state: InstallState, descriptor: ModelDescriptor?) -> String {
        let modelName = descriptor?.displayName ?? "Model"
        switch state {
        case .downloading:
            return "Downloading \(modelName)"
        case .downloaded:
            return "Downloaded \(modelName)"
        case .verifying:
            return "Verifying \(modelName)"
        case .compiling:
            return "Preparing \(modelName)"
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return modelName
        }
    }

    private func activeDownloadDetail(
        state: InstallState,
        detail: ModelInstallProgress?,
        estimatedTotalBytes: Int64?
    ) -> String {
        switch state {
        case .downloading(let progress):
            if let detail,
               let completedBytes = detail.completedBytes,
               let totalBytes = detail.totalBytes,
               totalBytes > 0 {
                let prefix = detail.isEstimated ? "Approx. " : ""
                return "\(prefix)\(exampleByteCountTitle(completedBytes)) of \(exampleByteCountTitle(totalBytes))"
            }
            if let estimatedTotalBytes, estimatedTotalBytes > 0 {
                let completedBytes = Int64((progress * Double(estimatedTotalBytes)).rounded())
                return "Approx. \(exampleByteCountTitle(completedBytes)) of \(exampleByteCountTitle(estimatedTotalBytes))"
            }
            let prefix = detail?.isEstimated == true ? "~" : ""
            return "\(prefix)\(Int((progress * 100).rounded()))%"
        case .downloaded:
            return "Download complete"
        case .verifying:
            return "Checking files"
        case .compiling:
            return "Preparing runtime"
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return ""
        }
    }

    private func activeDownloadProgress(for state: InstallState) -> Double {
        switch state {
        case .downloading(let progress):
            return max(0, min(progress, 1))
        case .downloaded, .verifying, .compiling:
            return 1
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return 0
        }
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
                            requirements: viewModel.chatRequirements,
                            beforeSend: {
                                try await viewModel.validateSelectedModelForChat()
                            }
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
                        models: viewModel.chatSelectableModels,
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    CatalogOverviewCard(
                        totalModels: viewModel.models.count,
                        readyModels: readyModelCount,
                        downloadableModels: viewModel.downloadableModels.count,
                        installedModels: installedModelCount,
                        installedSize: downloadsViewModel.installedStorageTitle,
                        catalogStatus: viewModel.catalogStatus
                    )

                    ForEach(modelSections) { section in
                        if !section.models.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 2)

                                VStack(spacing: 0) {
                                    ForEach(Array(section.models.enumerated()), id: \.element.id) { index, descriptor in
                                        modelCard(for: descriptor)

                                        if index < section.models.count - 1 {
                                            Divider()
                                                .padding(.leading, 18)
                                                .padding(.trailing, 18)
                                        }
                                    }
                                }
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(ExampleDemoBackground().ignoresSafeArea())
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
            isSelected: descriptor.id == viewModel.selectedModel?.id,
            installState: presentation.installState(for: descriptor),
            progressDetail: downloadsViewModel.progressDetail(for: descriptor.id),
            installedSizeBytes: downloadsViewModel.storageBytes(for: descriptor.id),
            isInstallButtonDisabled: downloadsViewModel.isInstallButtonDisabled(for: descriptor.id),
            selectAction: presentation.isReadyForChat(descriptor) ? {
                viewModel.selectedModelID = descriptor.id
            } : nil,
            installAction: installAction(for: descriptor),
            cancelAction: cancelAction(for: descriptor),
            deleteAction: deleteAction(for: descriptor)
        ) {
            presentedDetail = PresentedModelDetail(descriptor: descriptor)
        }
    }

    private var catalogModels: [ModelDescriptor] {
        viewModel.models.sorted { $0.displayName < $1.displayName }
    }

    private var modelSections: [ExampleModelSection] {
        let ready = catalogModels.filter(presentation.isReadyForChat)
        let downloading = catalogModels.filter { descriptor in
            !presentation.isReadyForChat(descriptor) && downloadsViewModel.isInstalling(descriptor.id)
        }
        let recommended = catalogModels.filter { descriptor in
            !presentation.isReadyForChat(descriptor)
                && !downloadsViewModel.isInstalling(descriptor.id)
                && isRecommended(descriptor)
        }
        let available = catalogModels.filter { descriptor in
            !presentation.isReadyForChat(descriptor)
                && !downloadsViewModel.isInstalling(descriptor.id)
                && !isRecommended(descriptor)
        }
        return [
            ExampleModelSection(id: .ready, models: ready),
            ExampleModelSection(id: .recommended, models: recommended),
            ExampleModelSection(id: .downloading, models: downloading),
            ExampleModelSection(id: .available, models: available)
        ]
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

    private func deleteAction(for descriptor: ModelDescriptor) -> (() async -> Void)? {
        guard downloadsViewModel.isInstalled(descriptor.id) else {
            return nil
        }
        return {
            await downloadsViewModel.delete(descriptor.id)
            await viewModel.refresh()
        }
    }

    private func isRecommended(_ descriptor: ModelDescriptor) -> Bool {
        let recommendedTags = [
            "recommended",
            "iphone-recommended",
            "balanced",
            "quality",
            "iphone-pro",
            "starter",
            "iphone-entry"
        ]
        return descriptor.tags.contains { recommendedTags.contains($0) }
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

private struct ExampleModelSection: Identifiable {
    let id: ExampleModelSectionID
    let models: [ModelDescriptor]

    var title: String {
        id.title
    }
}

private enum ExampleModelSectionID: Hashable {
    case ready
    case downloading
    case recommended
    case available

    var title: String {
        switch self {
        case .ready:
            return "Ready to Chat"
        case .downloading:
            return "Downloading"
        case .recommended:
            return "Recommended"
        case .available:
            return "Available Models"
        }
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
        viewModel.isReadyForChat(descriptor)
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
