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

    public func updateDescriptors(_ descriptors: [ModelDescriptor]) async {
        self.descriptors = descriptors
        for descriptor in descriptors where installStates[descriptor.id] == nil {
            installStates[descriptor.id] = .notInstalled
        }
        reconcilePartialArtifactProgress()
        do {
            try await refreshStorageUsage()
            self.reconcilePartialArtifactProgress()
        } catch {
            lastErrorMessage = Self.presentationMessage(for: error)
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
            reconcilePartialArtifactProgress()
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
        reconcilePartialArtifactProgress()
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
        let partialModelIDs = self.partialModelIDs.filter { partialBytes(for: $0) > 0 }
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
            let percentTitle = DownloadProgressPresentation.percentTitle(for: progress)
            return "Downloading \(percentTitle)"
        case .paused(let progress):
            let percentTitle = DownloadProgressPresentation.percentTitle(for: progress)
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
            return partialBytes(for: modelID) > 0
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
        partialModelIDs
            .map { partialBytes(for: $0) }
            .reduce(0, +)
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

    private var partialModelIDs: Set<ModelID> {
        Set(storageUsage.modelBytes.keys)
            .union(installProgress.keys)
            .union(installStates.keys)
            .filter { !isInstalled($0) }
    }

    private func partialBytes(for modelID: ModelID) -> Int64 {
        max(storageUsage.modelBytes[modelID] ?? 0, installProgress[modelID]?.completedBytes ?? 0)
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
            installStates[id] = stateForPresentation(modelID: id, incomingState: state)
        case .progress(let id, let progress):
            updateDownloadingProgress(modelID: id, progress: progress)
        case .progressDetail(let id, let detail):
            updateProgressDetail(modelID: id, detail: detail)
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

    private func stateForPresentation(modelID: ModelID, incomingState: InstallState) -> InstallState {
        guard case .downloading(let progress) = incomingState else {
            return incomingState
        }
        return .downloading(progress: mergedDownloadProgress(modelID: modelID, incomingProgress: progress))
    }

    private func updateDownloadingProgress(modelID: ModelID, progress: Double) {
        installStates[modelID] = .downloading(progress: mergedDownloadProgress(
            modelID: modelID,
            incomingProgress: progress
        ))
    }

    private func updateProgressDetail(modelID: ModelID, detail: ModelInstallProgress) {
        let existingProgress = progress(for: modelID) ?? 0
        let incomingProgress = DownloadProgressPresentation.normalizedFraction(detail.fractionCompleted)
        guard installProgress[modelID] != nil, existingProgress > incomingProgress else {
            installProgress[modelID] = detail
            installStates[modelID] = .downloading(progress: incomingProgress)
            return
        }

        installStates[modelID] = .downloading(progress: existingProgress)
    }

    private func mergedDownloadProgress(modelID: ModelID, incomingProgress: Double) -> Double {
        let normalizedIncoming = DownloadProgressPresentation.normalizedFraction(incomingProgress)
        guard installProgress[modelID] != nil else {
            return normalizedIncoming
        }
        return max(progress(for: modelID) ?? 0, normalizedIncoming)
    }

    private func handleInstallError(_ error: Error, descriptor: ModelDescriptor) async {
        if let llmError = error as? LLMError, llmError == .cancelled {
            if installStates[descriptor.id] != .notInstalled {
                installStates[descriptor.id] = .paused(progress: progress(for: descriptor.id) ?? 0)
            } else {
                installProgress[descriptor.id] = nil
            }
            try? await refreshStorageUsage()
            reconcilePartialArtifactProgress()
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
        for modelID in trackedIDs {
            let alias = Self.storageAlias(for: modelID)
            if alias != modelID, modelBytes[modelID] != nil {
                modelBytes[alias] = nil
                continue
            }
            guard modelBytes[modelID] == nil else {
                continue
            }
            let bytes = try await maintenanceService.storageUsage(for: modelID)
            if bytes > 0 {
                modelBytes[modelID] = bytes
                if alias != modelID {
                    modelBytes[alias] = nil
                }
            }
        }
        storageUsage = ModelStorageUsage(
            totalBytes: modelBytes.values.reduce(0, +),
            modelBytes: modelBytes,
            availableBytes: baseUsage.availableBytes,
            capacityBytes: baseUsage.capacityBytes
        )
    }

    private func reconcilePartialArtifactProgress() {
        guard maintenanceService != nil else {
            return
        }

        for descriptor in descriptors {
            let modelID = descriptor.id
            let storedBytes = storageUsage.modelBytes[modelID] ?? 0
            let state = installStates[modelID] ?? .notInstalled

            switch state {
            case .notInstalled where storedBytes > 0:
                guard let detail = inferredProgressDetail(for: descriptor, progress: nil, storedBytes: storedBytes) else {
                    continue
                }
                installStates[modelID] = .paused(progress: detail.fractionCompleted)
                installProgress[modelID] = detail
            case .downloading(let progress), .paused(let progress):
                if let detail = inferredProgressDetail(for: descriptor, progress: progress, storedBytes: storedBytes) {
                    installProgress[modelID] = detail
                }
            case .notInstalled, .downloaded, .verifying, .compiling, .ready, .warming, .active, .failed, .evicted:
                break
            }
        }
    }

    private func inferredProgressDetail(
        for descriptor: ModelDescriptor,
        progress: Double?,
        storedBytes: Int64
    ) -> ModelInstallProgress? {
        let stateFraction = progress.map(DownloadProgressPresentation.normalizedFraction)
        guard let expected = expectedDownloadSize(for: descriptor), expected.bytes > 0 else {
            guard storedBytes > 0 || (stateFraction ?? 0) > 0 else {
                return nil
            }
            return ModelInstallProgress(
                fractionCompleted: stateFraction ?? 0,
                completedBytes: storedBytes > 0 ? storedBytes : nil,
                totalBytes: nil,
                isEstimated: true
            )
        }

        let storedFraction = Double(storedBytes) / Double(expected.bytes)
        let fraction = min(max(stateFraction ?? storedFraction, storedFraction, 0), 1)
        guard fraction > 0 else {
            return nil
        }

        let inferredBytes = Int64((fraction * Double(expected.bytes)).rounded())
        let completedBytes = min(max(storedBytes, inferredBytes), expected.bytes)
        return ModelInstallProgress(
            fractionCompleted: fraction,
            completedBytes: completedBytes,
            totalBytes: expected.bytes,
            isEstimated: expected.isEstimated
        )
    }

    private func expectedDownloadSize(for descriptor: ModelDescriptor) -> (bytes: Int64, isEstimated: Bool)? {
        if let artifacts = descriptor.source?.artifacts, !artifacts.isEmpty {
            let knownBytes = artifacts.compactMap(\.byteCount)
            let totalBytes = knownBytes.reduce(Int64(0), +)
            if knownBytes.count == artifacts.count, totalBytes > 0 {
                return (totalBytes, false)
            }
        }

        if let estimatedDownloadSizeBytes = descriptor.estimatedDownloadSizeBytes, estimatedDownloadSizeBytes > 0 {
            return (estimatedDownloadSizeBytes, true)
        }

        return nil
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

    private static func storageAlias(for modelID: ModelID) -> ModelID {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let rawValue = modelID.rawValue.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
        return ModelID(rawValue: rawValue)
    }
}
