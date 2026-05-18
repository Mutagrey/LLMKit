import Foundation
import LLMCore
import LLMUIDownloads
import SwiftUI

struct ModelsTab: View {
    let viewModel: DemoViewModel
    let downloadsViewModel: ModelDownloadsViewModel

    @State private var presentedModel: PresentedModel?
    @State private var searchText = ""
    @State private var backendFilter: ModelBackendFilter = .all
    @State private var installFilter: ModelInstallFilter = .all
    @State private var sortOrder: ModelSortOrder = .recommended
    @State private var grouping: ModelGrouping = .backend

    private var presentation: ModelPresentation {
        ModelPresentation(viewModel: viewModel, downloadsViewModel: downloadsViewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(modelSections) { section in
                    Section(section.title) {
                        ForEach(section.models, id: \.self) { descriptor in
                            modelCard(for: descriptor)
                        }
                    }
                }
            }
            .navigationTitle("Models")
            .searchable(text: $searchText, prompt: "Search models")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    filterMenu
                    displayMenu
                }
            }
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
            .sheet(item: $presentedModel) { item in
                NavigationStack {
                    ModelDetailView(
                        descriptor: item.descriptor,
                        status: presentation.statusText(for: item.descriptor),
                        isAvailable: presentation.isReadyForChat(item.descriptor)
                    )
                    .navigationTitle(item.descriptor.displayName)
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Backend", selection: $backendFilter) {
                ForEach(ModelBackendFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            Picker("State", selection: $installFilter) {
                ForEach(ModelInstallFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var displayMenu: some View {
        Menu {
            Picker("Sort", selection: $sortOrder) {
                ForEach(ModelSortOrder.allCases, id: \.self) { order in
                    Text(order.title).tag(order)
                }
            }
            Picker("Group", selection: $grouping) {
                ForEach(ModelGrouping.allCases, id: \.self) { group in
                    Text(group.title).tag(group)
                }
            }
        } label: {
            Label("View", systemImage: "square.grid.2x2")
        }
    }

    private var catalogModels: [ModelDescriptor] {
        sortOrder.sorted(filteredModels, presentation: presentation)
    }

    private var filteredModels: [ModelDescriptor] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.models.filter { descriptor in
            backendFilter.matches(descriptor) &&
                installFilter.matches(descriptor, presentation: presentation) &&
                matchesSearch(descriptor, query: query)
        }
    }

    private var modelSections: [ModelSection] {
        grouping.sections(for: catalogModels, presentation: presentation)
    }

    private var trackedDownloadablesKey: String {
        viewModel.downloadableModels.map { $0.id.rawValue }.joined(separator: "|")
    }

    private var installLifecycleKey: String {
        viewModel.downloadableModels
            .map { "\($0.id.rawValue):\(installLifecyclePhase(for: $0.id))" }
            .joined(separator: "|")
    }

    private func modelCard(for descriptor: ModelDescriptor) -> some View {
        ModelCatalogCardView(
            descriptor: descriptor,
            status: presentation.statusText(for: descriptor),
            isAvailable: presentation.isReadyForChat(descriptor),
            isSelected: descriptor.id == viewModel.selectedModel?.id,
            installState: presentation.installState(for: descriptor),
            progressDetail: downloadsViewModel.progressDetail(for: descriptor.id),
            installedSizeBytes: downloadsViewModel.storageBytes(for: descriptor.id),
            isInstallButtonDisabled: downloadsViewModel.isInstallButtonDisabled(for: descriptor.id),
            selectionAction: presentation.isReadyForChat(descriptor) ? {
                viewModel.selectedModelID = descriptor.id
            } : nil,
            installAction: installAction(for: descriptor),
            cancelAction: cancelAction(for: descriptor),
            deleteAction: deleteAction(for: descriptor),
            detailsAction: {
                presentedModel = PresentedModel(descriptor: descriptor)
            }
        )
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
        guard downloadsViewModel.canDeleteArtifacts(for: descriptor.id) else {
            return nil
        }
        return {
            await downloadsViewModel.delete(descriptor.id)
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
        downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
        await downloadsViewModel.refresh()
    }

    private func matchesSearch(_ descriptor: ModelDescriptor, query: String) -> Bool {
        guard !query.isEmpty else {
            return true
        }
        let searchableText = [
            descriptor.displayName,
            descriptor.id.rawValue,
            descriptor.family.title,
            demoBackendTitle(descriptor.backend),
            descriptor.quantization?.format,
            descriptor.source?.repository,
            descriptor.tags.joined(separator: " ")
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        return searchableText.contains(query)
    }
}

private struct ModelSection: Identifiable {
    let title: String
    let models: [ModelDescriptor]

    var id: String {
        title
    }
}

private struct PresentedModel: Identifiable {
    let descriptor: ModelDescriptor

    var id: ModelID {
        descriptor.id
    }
}

@MainActor
private struct ModelPresentation {
    let viewModel: DemoViewModel
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

private enum ModelBackendFilter: CaseIterable, Hashable {
    case all
    case apple
    case mlx
    case gguf
    case remote

    var title: String {
        switch self {
        case .all:
            return "All Backends"
        case .apple:
            return "Apple"
        case .mlx:
            return "MLX"
        case .gguf:
            return "GGUF"
        case .remote:
            return "Remote"
        }
    }

    func matches(_ descriptor: ModelDescriptor) -> Bool {
        switch self {
        case .all:
            return true
        case .apple:
            return descriptor.backend == .foundationModels
        case .mlx:
            return descriptor.backend == .mlx
        case .gguf:
            return descriptor.backend == .llamaCpp
        case .remote:
            return descriptor.backend == .remote
        }
    }
}

private enum ModelInstallFilter: CaseIterable, Hashable {
    case all
    case ready
    case downloadable
    case installed

    var title: String {
        switch self {
        case .all:
            return "All States"
        case .ready:
            return "Ready"
        case .downloadable:
            return "Downloadable"
        case .installed:
            return "Installed"
        }
    }

    @MainActor
    func matches(_ descriptor: ModelDescriptor, presentation: ModelPresentation) -> Bool {
        switch self {
        case .all:
            return true
        case .ready:
            return presentation.isReadyForChat(descriptor)
        case .downloadable:
            return presentation.installState(for: descriptor) != nil
        case .installed:
            return presentation.installState(for: descriptor).map(Self.isInstalled) ?? presentation.isReadyForChat(descriptor)
        }
    }

    private static func isInstalled(_ state: InstallState) -> Bool {
        switch state {
        case .ready, .warming, .active:
            return true
        case .notInstalled, .downloading, .downloaded, .verifying, .compiling, .failed, .evicted:
            return false
        }
    }
}

private enum ModelSortOrder: CaseIterable, Hashable {
    case recommended
    case name
    case size
    case memory

    var title: String {
        switch self {
        case .recommended:
            return "Recommended"
        case .name:
            return "Name"
        case .size:
            return "Download Size"
        case .memory:
            return "Memory"
        }
    }

    @MainActor
    func sorted(_ models: [ModelDescriptor], presentation: ModelPresentation) -> [ModelDescriptor] {
        models.sorted { lhs, rhs in
            switch self {
            case .recommended:
                return recommendedKey(lhs, presentation: presentation) < recommendedKey(rhs, presentation: presentation)
            case .name:
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            case .size:
                return sizeKey(lhs) < sizeKey(rhs)
            case .memory:
                return memoryKey(lhs) < memoryKey(rhs)
            }
        }
    }

    @MainActor
    private func recommendedKey(_ descriptor: ModelDescriptor, presentation: ModelPresentation) -> ModelSortKey {
        ModelSortKey(
            readyRank: presentation.isReadyForChat(descriptor) ? 0 : 1,
            backendRank: backendRank(descriptor.backend),
            tagRank: tagRank(descriptor.tags),
            size: descriptor.estimatedDownloadSizeBytes ?? .max,
            name: descriptor.displayName
        )
    }

    private func sizeKey(_ descriptor: ModelDescriptor) -> ModelSortKey {
        ModelSortKey(
            readyRank: 0,
            backendRank: 0,
            tagRank: 0,
            size: descriptor.estimatedDownloadSizeBytes ?? .max,
            name: descriptor.displayName
        )
    }

    private func memoryKey(_ descriptor: ModelDescriptor) -> ModelSortKey {
        ModelSortKey(
            readyRank: 0,
            backendRank: descriptor.minimumRAMGB ?? .max,
            tagRank: 0,
            size: descriptor.estimatedDownloadSizeBytes ?? .max,
            name: descriptor.displayName
        )
    }

    private func backendRank(_ backend: BackendKind) -> Int {
        switch backend {
        case .foundationModels:
            return 0
        case .mlx:
            return 1
        case .llamaCpp:
            return 2
        case .remote:
            return 3
        case .coreML:
            return 4
        case .executorch:
            return 5
        case .onnxRuntime:
            return 6
        case .custom:
            return 7
        }
    }

    private func tagRank(_ tags: [String]) -> Int {
        if tags.contains("starter") || tags.contains("iphone-entry") {
            return 0
        }
        if tags.contains("balanced") || tags.contains("iphone-recommended") {
            return 1
        }
        if tags.contains("quality") || tags.contains("iphone-pro") {
            return 2
        }
        return 3
    }
}

private struct ModelSortKey: Comparable {
    let readyRank: Int
    let backendRank: Int
    let tagRank: Int
    let size: Int64
    let name: String

    static func < (lhs: ModelSortKey, rhs: ModelSortKey) -> Bool {
        if lhs.readyRank != rhs.readyRank {
            return lhs.readyRank < rhs.readyRank
        }
        if lhs.backendRank != rhs.backendRank {
            return lhs.backendRank < rhs.backendRank
        }
        if lhs.tagRank != rhs.tagRank {
            return lhs.tagRank < rhs.tagRank
        }
        if lhs.size != rhs.size {
            return lhs.size < rhs.size
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

private enum ModelGrouping: CaseIterable, Hashable {
    case backend
    case family
    case installState
    case none

    var title: String {
        switch self {
        case .backend:
            return "Backend"
        case .family:
            return "Family"
        case .installState:
            return "State"
        case .none:
            return "None"
        }
    }

    @MainActor
    func sections(for models: [ModelDescriptor], presentation: ModelPresentation) -> [ModelSection] {
        switch self {
        case .backend:
            return grouped(models, title: { demoBackendTitle($0.backend) })
        case .family:
            return grouped(models, title: { $0.family.title })
        case .installState:
            return grouped(models, title: { installTitle(for: $0, presentation: presentation) })
        case .none:
            return [ModelSection(title: "All Models", models: models)]
        }
    }

    private func grouped(
        _ models: [ModelDescriptor],
        title: (ModelDescriptor) -> String
    ) -> [ModelSection] {
        Dictionary(grouping: models, by: title)
            .map { ModelSection(title: $0.key, models: $0.value) }
            .sorted { $0.title < $1.title }
    }

    @MainActor
    private func installTitle(for descriptor: ModelDescriptor, presentation: ModelPresentation) -> String {
        if presentation.isReadyForChat(descriptor) {
            return "Ready"
        }
        if presentation.installState(for: descriptor) != nil {
            return "Downloadable"
        }
        return "Unavailable"
    }
}
