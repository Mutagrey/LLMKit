import LLMCore
import LLMUIModels
import SwiftUI

struct ModelsTab: View {
    let viewModel: DemoViewModel
    let downloadsViewModel: ModelDownloadsViewModel

    var body: some View {
        NavigationStack {
            ModelListView(
                models: viewModel.models,
                selectedModelID: viewModel.selectedModel?.id,
                isRefreshing: viewModel.isRefreshing,
                errorMessage: downloadsViewModel.lastErrorMessage ?? viewModel.lastErrorMessage,
                storageSummary: storageSummary,
                statusText: statusText(for:),
                isReadyForChat: viewModel.isReadyForChat(_:),
                installState: installState(for:),
                progressDetail: { downloadsViewModel.progressDetail(for: $0.id) },
                installedSizeBytes: { downloadsViewModel.storageBytes(for: $0.id) },
                isInstallButtonDisabled: { downloadsViewModel.isInstallButtonDisabled(for: $0.id) },
                canDeleteArtifacts: { downloadsViewModel.canDeleteArtifacts(for: $0.id) },
                selectAction: { viewModel.selectedModelID = $0.id },
                installAction: { await downloadsViewModel.beginInstall($0) },
                cancelAction: { descriptor in
                    await downloadsViewModel.cancelInstall(descriptor.id)
                    await viewModel.refresh()
                },
                deleteAction: { descriptor in
                    await downloadsViewModel.delete(descriptor.id)
                    await viewModel.refresh()
                },
                refreshAction: refreshAll
            )
            .task(id: downloadableModelsKey) {
                await downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
            }
            .task(id: installLifecycleKey) {
                guard !viewModel.downloadableModels.isEmpty else {
                    return
                }
                await viewModel.refresh()
            }
        }
    }

    private var downloadableModelsKey: String {
        viewModel.downloadableModels.map(\.id.rawValue).joined(separator: "|")
    }

    private var installLifecycleKey: String {
        viewModel.downloadableModels
            .map { "\($0.id.rawValue):\(downloadsViewModel.installState(for: $0.id))" }
            .joined(separator: "|")
    }

    private var storageSummary: ModelStorageSummary {
        ModelStorageSummary(
            downloadedModelCount: viewModel.downloadableModels.filter { downloadsViewModel.isInstalled($0.id) }.count,
            totalModelCount: viewModel.models.count,
            installedBytes: downloadsViewModel.installedStorageBytes,
            partialBytes: downloadsViewModel.partialStorageBytes,
            availableBytes: downloadsViewModel.storageUsage.availableBytes,
            capacityBytes: downloadsViewModel.storageUsage.capacityBytes
        )
    }

    private func installState(for descriptor: ModelDescriptor) -> InstallState? {
        guard viewModel.downloadableModels.contains(where: { $0.id == descriptor.id }) else {
            return nil
        }
        return downloadsViewModel.installState(for: descriptor.id)
    }

    private func statusText(for descriptor: ModelDescriptor) -> String {
        if installState(for: descriptor) != nil {
            return downloadsViewModel.statusText(for: descriptor.id)
        }
        return viewModel.statusText(for: descriptor)
    }

    private func refreshAll() async {
        await viewModel.refresh()
        await downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
        await downloadsViewModel.refresh()
    }
}
