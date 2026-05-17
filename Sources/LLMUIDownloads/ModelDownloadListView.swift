import Foundation
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                DownloadsOverviewCard(
                    totalModels: visibleDescriptors.count,
                    installedModels: installedDescriptors.count,
                    inProgressModels: inProgressDescriptors.count,
                    installedSize: viewModel.installedStorageTitle
                )

                if !installedDescriptors.isEmpty {
                    section(title: "Installed", descriptors: installedDescriptors)
                }

                if !availableDescriptors.isEmpty {
                    section(title: "Available to Download", descriptors: availableDescriptors)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
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

    private func section(title: String, descriptors: [ModelDescriptor]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(descriptors.enumerated()), id: \.element.id) { index, descriptor in
                    card(for: descriptor)
                    if index < descriptors.count - 1 {
                        Divider()
                            .padding(.horizontal, 18)
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
            canDeleteArtifacts: viewModel.canDeleteArtifacts(for: descriptor.id),
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
    public private(set) var cancelingModelIDs: Set<ModelID>
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
        self.cancelingModelIDs = []
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
            lastErrorMessage = Self.presentationMessage(for: error)
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
                await handleInstallEvent(event)
            }
        } catch {
            await handleInstallError(error, descriptor: descriptor)
        }
        finishTrackedInstall(for: descriptor.id)
    }

    public func beginInstall(_ descriptor: ModelDescriptor) async {
        guard
            let lifecycleService,
            installTasks[descriptor.id] == nil,
            !cancelingModelIDs.contains(descriptor.id)
        else {
            return
        }

        lastErrorMessage = nil
        installingModelIDs.insert(descriptor.id)
        installTasks[descriptor.id] = Task { [weak self, lifecycleService] in
            do {
                for try await event in lifecycleService.install(descriptor) {
                    await self?.handleInstallEvent(event)
                }
            } catch {
                await self?.handleInstallError(error, descriptor: descriptor)
            }
            self?.finishTrackedInstall(for: descriptor.id)
        }
    }

    public func cancelInstall(_ modelID: ModelID) async {
        guard let task = installTasks[modelID] else {
            return
        }
        cancelingModelIDs.insert(modelID)
        task.cancel()
        await task.value
        cancelingModelIDs.remove(modelID)
        installTasks[modelID] = nil
        installingModelIDs.remove(modelID)
        if !isInstalled(modelID) {
            installStates[modelID] = .notInstalled
            installProgress[modelID] = nil
        }
        try? await refreshStorageUsage()
    }

    public func delete(_ modelID: ModelID) async {
        guard let maintenanceService else {
            return
        }
        lastErrorMessage = nil
        if let task = installTasks[modelID] {
            cancelingModelIDs.insert(modelID)
            task.cancel()
            await task.value
            cancelingModelIDs.remove(modelID)
            installTasks[modelID] = nil
        }
        do {
            try await maintenanceService.deleteInstalledModel(modelID)
            installStates[modelID] = .notInstalled
            installProgress[modelID] = nil
            models.removeAll { $0.descriptor.id == modelID }
            try await refreshStorageUsage()
        } catch {
            lastErrorMessage = Self.presentationMessage(for: error)
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

    public func canDeleteArtifacts(for modelID: ModelID) -> Bool {
        guard maintenanceService != nil, !cancelingModelIDs.contains(modelID) else {
            return false
        }
        if isInstalled(modelID) {
            return true
        }
        switch installStates[modelID] {
        case .failed, .evicted:
            return true
        case .notInstalled, .downloading, .downloaded, .verifying, .compiling, .ready, .warming, .active, nil:
            return (storageBytes(for: modelID) ?? 0) > 0
        }
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
        installingModelIDs.contains(modelID) || cancelingModelIDs.contains(modelID) || isInstalled(modelID)
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

    private func handleInstallEvent(_ event: ModelInstallEvent) async {
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
            installStates[id] = .failed(Self.presentationMessage(for: error))
            installProgress[id] = nil
            installingModelIDs.remove(id)
            installTasks[id] = nil
            try? await refreshStorageUsage()
        }
    }

    private func handleInstallError(_ error: Error, descriptor: ModelDescriptor) async {
        if let llmError = error as? LLMError, llmError == .cancelled {
            installStates[descriptor.id] = .notInstalled
            installProgress[descriptor.id] = nil
            try? await refreshStorageUsage()
        } else {
            let message = Self.presentationMessage(for: error)
            installStates[descriptor.id] = .failed(message)
            installProgress[descriptor.id] = nil
            lastErrorMessage = message
            try? await refreshStorageUsage()
        }
    }

    private func finishTrackedInstall(for modelID: ModelID) {
        installingModelIDs.remove(modelID)
        if cancelingModelIDs.contains(modelID) == false {
            installTasks[modelID] = nil
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
        let baseUsage = try await maintenanceService.storageUsage()
        var modelBytes = baseUsage.modelBytes
        let trackedIDs = Set(descriptors.map(\.id))
            .union(models.map(\.descriptor.id))
            .union(installStates.keys)
        for modelID in trackedIDs where modelBytes[modelID] == nil {
            let bytes = try await maintenanceService.storageUsage(for: modelID)
            if bytes > 0 {
                modelBytes[modelID] = bytes
            }
        }
        storageUsage = ModelStorageUsage(
            totalBytes: modelBytes.values.reduce(0, +),
            modelBytes: modelBytes
        )
    }

    private static func presentationMessage(for error: Error) -> String {
        if let llmError = error as? LLMError {
            return presentationMessage(for: llmError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch URLError.Code(rawValue: nsError.code) {
            case .networkConnectionLost:
                return "Network connection was lost. Retry the installation."
            case .timedOut:
                return "Download timed out. Retry the installation."
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return "Could not connect. Retry the installation."
            case .notConnectedToInternet:
                return "No internet connection."
            case .cancelled:
                return "Cancelled."
            default:
                return "Download failed. Retry the installation."
            }
        }

        return "Operation failed. Retry the operation."
    }

    private static func presentationMessage(for error: LLMError) -> String {
        switch error {
        case .downloadFailed(let message),
             .verificationFailed(let message),
             .executionFailed(let message),
             .toolExecutionFailed(let message),
             .invalidStructuredOutput(let message),
             .unsupportedLocale(let message),
             .modelSelectionFailed(let message):
            return message
        case .modelNotInstalled(let modelID):
            return "\(modelID.rawValue) is not installed."
        case .unsupportedCapabilities:
            return "Unsupported capabilities."
        case .compilationFailed:
            return "Compilation failed."
        case .unavailable:
            return "Unavailable."
        case .cancelled:
            return "Cancelled."
        }
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        }
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
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

public enum LLMUIDownloadsNamespace {}
