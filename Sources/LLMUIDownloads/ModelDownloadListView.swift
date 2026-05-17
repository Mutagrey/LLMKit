import LLMCore
import LLMModelLifecycle
import LLMObservability
import LLMProtocols
import Observation
import SwiftUI

public struct ModelDownloadListView: View {
    @State private var viewModel: ModelDownloadsViewModel
    private let configuredDescriptors: [ModelDescriptor]

    public init(
        models: [InstalledModelRecord] = [],
        descriptors: [ModelDescriptor] = [],
        lifecycleService: (any ModelLifecycleService)? = nil
    ) {
        self._viewModel = State(initialValue: ModelDownloadsViewModel(
            models: models,
            descriptors: descriptors,
            lifecycleService: lifecycleService
        ))
        self.configuredDescriptors = descriptors
    }

    public var body: some View {
        List {
            Section {
                DownloadsOverviewCard(
                    totalModels: visibleDescriptors.count,
                    installedModels: installedDescriptors.count,
                    inProgressModels: inProgressDescriptors.count,
                    installedSize: viewModel.installedStorageTitle
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if !installedDescriptors.isEmpty {
                Section("Installed") {
                    ForEach(installedDescriptors, id: \.id) { descriptor in
                        card(for: descriptor)
                    }
                }
            }

            if !availableDescriptors.isEmpty {
                Section("Available to Download") {
                    ForEach(availableDescriptors, id: \.id) { descriptor in
                        card(for: descriptor)
                    }
                }
            }
        }
        .overlay {
            if let lastErrorMessage = viewModel.lastErrorMessage {
                VStack {
                    Spacer()
                    Text(lastErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background)
                }
            }
        }
        .task {
            viewModel.updateDescriptors(configuredDescriptors)
            await viewModel.refresh()
        }
    }

    private var visibleDescriptors: [ModelDescriptor] {
        var seen = Set<ModelID>()
        return (configuredDescriptors + viewModel.models.map(\.descriptor))
            .filter { descriptor in
            seen.insert(descriptor.id).inserted
        }
        .sorted { lhs, rhs in
            if viewModel.isInstalled(lhs.id) != viewModel.isInstalled(rhs.id) {
                return viewModel.isInstalled(lhs.id)
            }
            return lhs.displayName < rhs.displayName
        }
    }

    private var installedDescriptors: [ModelDescriptor] {
        visibleDescriptors.filter { viewModel.isInstalled($0.id) }
    }

    private var availableDescriptors: [ModelDescriptor] {
        visibleDescriptors.filter { !viewModel.isInstalled($0.id) }
    }

    private var inProgressDescriptors: [ModelDescriptor] {
        visibleDescriptors.filter { viewModel.isInstalling($0.id) }
    }

    private func card(for descriptor: ModelDescriptor) -> some View {
        ModelDownloadCardView(
            descriptor: descriptor,
            state: viewModel.installState(for: descriptor.id),
            progressDetail: viewModel.progressDetail(for: descriptor.id),
            installedSizeBytes: viewModel.storageBytes(for: descriptor.id),
            isInstallButtonDisabled: viewModel.isInstallButtonDisabled(for: descriptor.id)
        ) {
            await viewModel.beginInstall(descriptor)
        } cancelAction: {
            await viewModel.cancelInstall(descriptor.id)
        } deleteAction: {
            await viewModel.delete(descriptor.id)
        }
    }
}

@MainActor
@Observable
public final class ModelDownloadsViewModel {
    public private(set) var models: [InstalledModelRecord]
    public private(set) var installStates: [ModelID: InstallState]
    public private(set) var installProgress: [ModelID: ModelInstallProgress]
    public private(set) var installingModelIDs: Set<ModelID>
    public private(set) var storageUsage: ModelStorageUsage
    public private(set) var lastErrorMessage: String?
    @ObservationIgnored
    private var descriptors: [ModelDescriptor]
    @ObservationIgnored
    private let lifecycleService: (any ModelLifecycleService)?
    @ObservationIgnored
    private let maintenanceService: (any ModelLifecycleMaintenanceService)?
    @ObservationIgnored
    private var installTasks: [ModelID: Task<Void, Never>]

    public init(
        models: [InstalledModelRecord] = [],
        descriptors: [ModelDescriptor] = [],
        lifecycleService: (any ModelLifecycleService)? = nil
    ) {
        self.models = models
        self.installStates = Dictionary(uniqueKeysWithValues: models.map { ($0.descriptor.id, $0.installState) })
        self.installProgress = [:]
        self.installingModelIDs = []
        self.storageUsage = .empty
        self.descriptors = descriptors
        self.lifecycleService = lifecycleService
        self.maintenanceService = lifecycleService as? any ModelLifecycleMaintenanceService
        self.installTasks = [:]
    }

    public func replaceModels(_ models: [InstalledModelRecord]) {
        self.models = models
        self.installStates = Dictionary(uniqueKeysWithValues: models.map { ($0.descriptor.id, $0.installState) })
        self.installProgress = [:]
    }

    public func updateDescriptors(_ descriptors: [ModelDescriptor]) {
        self.descriptors = descriptors
        for descriptor in descriptors where installStates[descriptor.id] == nil {
            installStates[descriptor.id] = .notInstalled
        }
    }

    public func refresh() async {
        guard let lifecycleService else {
            return
        }
        lastErrorMessage = nil
        do {
            replaceModels(try await lifecycleService.installedModels())
            try await refreshInstallStates()
            try await refreshStorageUsage()
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    public func install(_ descriptor: ModelDescriptor) async {
        guard let lifecycleService else {
            return
        }
        lastErrorMessage = nil
        installingModelIDs.insert(descriptor.id)
        do {
            for try await event in lifecycleService.install(descriptor) {
                switch event {
                case .stateChanged(let id, let state):
                    installStates[id] = state
                case .progress(let id, let progress):
                    installStates[id] = .downloading(progress: progress)
                case .progressDetail(let id, let detail):
                    installStates[id] = .downloading(progress: detail.fractionCompleted)
                    installProgress[id] = detail
                case .completed(let record):
                    installStates[record.descriptor.id] = record.installState
                    installProgress[record.descriptor.id] = nil
                    installingModelIDs.remove(record.descriptor.id)
                    installTasks[record.descriptor.id] = nil
                    upsert(record)
                    try? await refreshStorageUsage()
                case .failed(let id, let error):
                    installStates[id] = .failed(String(describing: error))
                    installProgress[id] = nil
                    installingModelIDs.remove(id)
                    installTasks[id] = nil
                }
            }
        } catch {
            if let llmError = error as? LLMError, llmError == .cancelled {
                installStates[descriptor.id] = .notInstalled
                installProgress[descriptor.id] = nil
            } else {
                lastErrorMessage = String(describing: error)
            }
        }
        installingModelIDs.remove(descriptor.id)
        installTasks[descriptor.id] = nil
    }

    public func beginInstall(_ descriptor: ModelDescriptor) async {
        guard installTasks[descriptor.id] == nil else {
            return
        }

        installTasks[descriptor.id] = Task { [weak self] in
            await self?.install(descriptor)
        }
    }

    public func cancelInstall(_ modelID: ModelID) async {
        installTasks[modelID]?.cancel()
        installTasks[modelID] = nil
        installingModelIDs.remove(modelID)
        installStates[modelID] = .notInstalled
        installProgress[modelID] = nil
    }

    public func delete(_ modelID: ModelID) async {
        guard let maintenanceService else {
            return
        }
        lastErrorMessage = nil
        installTasks[modelID]?.cancel()
        installTasks[modelID] = nil
        do {
            try await maintenanceService.deleteInstalledModel(modelID)
            installStates[modelID] = .notInstalled
            installProgress[modelID] = nil
            models.removeAll { $0.descriptor.id == modelID }
            try await refreshStorageUsage()
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    public func statusText(for modelID: ModelID) -> String {
        switch installStates[modelID] ?? .notInstalled {
        case .notInstalled:
            return "Not installed"
        case .downloading(let progress):
            let prefix = installProgress[modelID]?.isEstimated == true ? "~" : ""
            return "Downloading \(prefix)\(Int((progress * 100).rounded()))%"
        case .downloaded:
            return "Downloaded"
        case .verifying:
            return "Verifying"
        case .compiling:
            return "Compiling"
        case .ready:
            return "Ready"
        case .warming:
            return "Warming"
        case .active:
            return "Active"
        case .failed(let message):
            return "Failed: \(message)"
        case .evicted(let reason):
            return "Evicted: \(String(describing: reason))"
        }
    }

    public func progress(for modelID: ModelID) -> Double? {
        guard case .downloading(let progress) = installStates[modelID] else {
            return nil
        }
        return progress
    }

    public func progressDetail(for modelID: ModelID) -> ModelInstallProgress? {
        installProgress[modelID]
    }

    public func storageBytes(for modelID: ModelID) -> Int64? {
        storageUsage.modelBytes[modelID]
    }

    public var installedStorageTitle: String {
        ByteCountFormatter.string(fromByteCount: storageUsage.totalBytes, countStyle: .file)
    }

    public func isInstalled(_ modelID: ModelID) -> Bool {
        switch installStates[modelID] {
        case .ready, .warming, .active:
            return true
        case .notInstalled, .downloading, .downloaded, .verifying, .compiling, .failed, .evicted, nil:
            return false
        }
    }

    public func isInstallButtonDisabled(for modelID: ModelID) -> Bool {
        installingModelIDs.contains(modelID) || isInstalled(modelID)
    }

    public func isInstalling(_ modelID: ModelID) -> Bool {
        switch installStates[modelID] {
        case .downloading, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .ready, .warming, .active, .failed, .evicted, nil:
            return false
        }
    }

    private func upsert(_ record: InstalledModelRecord) {
        if let index = models.firstIndex(where: { $0.descriptor.id == record.descriptor.id }) {
            models[index] = record
        } else {
            models.append(record)
        }
    }

    private func refreshInstallStates() async throws {
        guard let lifecycleService else {
            return
        }

        let trackedIDs = Set(descriptors.map(\.id)).union(models.map(\.descriptor.id))
        var resolvedStates = installStates
        for modelID in trackedIDs {
            let state = try await lifecycleService.state(for: modelID)
            resolvedStates[modelID] = state
            if case .downloading = state {
                continue
            }
            installProgress[modelID] = nil
        }
        installStates = resolvedStates
    }

    private func refreshStorageUsage() async throws {
        guard let maintenanceService else {
            storageUsage = .empty
            return
        }
        storageUsage = try await maintenanceService.storageUsage()
    }
}

private struct DownloadsOverviewCard: View {
    let totalModels: Int
    let installedModels: Int
    let inProgressModels: Int
    let installedSize: String

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                stat(title: "Catalog", value: "\(totalModels)", tint: .secondary)
                stat(title: "Installed", value: "\(installedModels)", tint: .green)
            }
            GridRow {
                stat(title: "In Progress", value: "\(inProgressModels)", tint: .blue)
                stat(title: "Storage", value: installedSize, tint: .orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

public enum LLMUIDownloadsNamespace {}
