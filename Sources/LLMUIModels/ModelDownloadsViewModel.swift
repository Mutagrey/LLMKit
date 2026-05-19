import Foundation
import LLMCore
import LLMProtocols
import Observation

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

    public func installState(for modelID: ModelID) -> InstallState {
        installStates[modelID] ?? .notInstalled
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
        installTasks[modelID] = nil
        installingModelIDs.remove(modelID)
        try? await refreshStorageUsage()
        await task.value
        if let state = await postCancellationState(for: modelID) {
            installStates[modelID] = state
            switch state {
            case .paused:
                break
            case .notInstalled, .downloading, .downloaded, .verifying, .compiling, .ready, .warming, .active, .failed, .evicted:
                installProgress[modelID] = nil
            }
        }
        cancelingModelIDs.remove(modelID)
        try? await refreshStorageUsage()
    }

    private func postCancellationState(for modelID: ModelID) async -> InstallState? {
        guard let lifecycleService else {
            return nil
        }

        var lastState: InstallState?
        for _ in 0..<20 {
            guard let state = try? await lifecycleService.state(for: modelID) else {
                return lastState
            }
            lastState = state
            switch state {
            case .downloading, .downloaded, .verifying, .compiling:
                try? await Task.sleep(nanoseconds: 10_000_000)
            case .notInstalled, .paused, .ready, .warming, .active, .failed, .evicted:
                return state
            }
        }
        return lastState
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

    public func clearPartialArtifacts() async {
        let partialModelIDs = storageUsage.modelBytes.keys.filter { !isInstalled($0) }
        for modelID in partialModelIDs {
            await delete(modelID)
        }
    }

    public func clearInstalledModels() async {
        let installedModelIDs = Set(models.map(\.descriptor.id))
            .union(storageUsage.modelBytes.keys)
            .filter { isInstalled($0) }
        for modelID in installedModelIDs {
            await delete(modelID)
        }
    }

    public func statusText(for modelID: ModelID) -> String {
        switch installStates[modelID] ?? .notInstalled {
        case .notInstalled:
            return "Not installed"
        case .downloading(let progress):
            let percentTitle = DownloadProgressPresentation.percentTitle(
                for: progress,
                isEstimated: installProgress[modelID]?.isEstimated == true
            )
            return "Downloading \(percentTitle)"
        case .paused(let progress):
            let percentTitle = DownloadProgressPresentation.percentTitle(
                for: progress,
                isEstimated: installProgress[modelID]?.isEstimated == true
            )
            return "Paused \(percentTitle)"
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
        switch installStates[modelID] {
        case .downloading(let progress), .paused(let progress):
            return DownloadProgressPresentation.normalizedFraction(progress)
        case .notInstalled, .downloaded, .verifying, .compiling, .ready, .warming, .active, .failed, .evicted, nil:
            return nil
        }
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
        case .notInstalled, .downloading, .paused, .downloaded, .verifying, .compiling, .ready, .warming, .active, nil:
            return (storageBytes(for: modelID) ?? 0) > 0
        }
    }

    public var installedStorageTitle: String {
        ByteCountFormatter.string(fromByteCount: installedStorageBytes, countStyle: .file)
    }

    public var installedStorageBytes: Int64 {
        storageUsage.modelBytes
            .filter { isInstalled($0.key) }
            .values
            .reduce(0, +)
    }

    public var partialStorageBytes: Int64 {
        max(storageUsage.totalBytes - installedStorageBytes, 0)
    }

    public func isInstalled(_ modelID: ModelID) -> Bool {
        switch installStates[modelID] {
        case .ready, .warming, .active:
            return true
        case .notInstalled, .downloading, .paused, .downloaded, .verifying, .compiling, .failed, .evicted, nil:
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
        case .notInstalled, .paused, .ready, .warming, .active, .failed, .evicted, nil:
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
            if installStates[descriptor.id] != .notInstalled {
                installStates[descriptor.id] = .paused(progress: progress(for: descriptor.id) ?? 0)
            } else {
                installProgress[descriptor.id] = nil
            }
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
            if case .paused = state {
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
            modelBytes: modelBytes,
            availableBytes: baseUsage.availableBytes,
            capacityBytes: baseUsage.capacityBytes
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

public enum LLMUIModelsNamespace {}
