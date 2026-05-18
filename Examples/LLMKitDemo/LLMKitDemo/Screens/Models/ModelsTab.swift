import LLMCore
import LLMUIDownloads
import SwiftUI

struct ModelsTab: View {
    let viewModel: DemoViewModel
    let downloadsViewModel: ModelDownloadsViewModel

    @State private var presentedModel: PresentedModel?

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

    private var catalogModels: [ModelDescriptor] {
        viewModel.models.sorted { $0.displayName < $1.displayName }
    }

    private var modelSections: [ModelSection] {
        Array(Set(catalogModels.map(\.family)))
            .sorted { $0.title < $1.title }
            .map { family in
                ModelSection(
                    family: family,
                    models: catalogModels.filter { $0.family == family }
                )
            }
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
}

private struct ModelSection: Identifiable {
    let family: ModelFamily
    let models: [ModelDescriptor]

    var id: ModelFamily {
        family
    }

    var title: String {
        family.title
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
