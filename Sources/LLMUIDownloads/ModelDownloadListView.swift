import LLMCore
import LLMModelLifecycle
import LLMObservability
import LLMProtocols
import SwiftUI

public struct ModelDownloadListView: View {
    private let models: [InstalledModelRecord]

    public init(models: [InstalledModelRecord] = []) {
        self.models = models
    }

    public var body: some View {
        List(models) { record in
            VStack(alignment: .leading) {
                Text(record.descriptor.displayName)
                Text(String(describing: record.installState)).font(.caption)
            }
        }
    }
}

public struct ModelInstallProgressView: View {
    private let state: InstallState

    public init(state: InstallState) {
        self.state = state
    }

    public var body: some View {
        Text(String(describing: state))
    }
}

@MainActor
public final class ModelDownloadsViewModel {
    public private(set) var models: [InstalledModelRecord]
    public private(set) var installStates: [ModelID: InstallState]
    public private(set) var lastErrorMessage: String?
    private let lifecycleService: (any ModelLifecycleService)?

    public init(models: [InstalledModelRecord] = [], lifecycleService: (any ModelLifecycleService)? = nil) {
        self.models = models
        self.installStates = Dictionary(uniqueKeysWithValues: models.map { ($0.descriptor.id, $0.installState) })
        self.lifecycleService = lifecycleService
    }

    public func replaceModels(_ models: [InstalledModelRecord]) {
        self.models = models
        self.installStates = Dictionary(uniqueKeysWithValues: models.map { ($0.descriptor.id, $0.installState) })
    }

    public func install(_ descriptor: ModelDescriptor) async {
        guard let lifecycleService else {
            return
        }
        lastErrorMessage = nil
        do {
            for try await event in lifecycleService.install(descriptor) {
                switch event {
                case .stateChanged(let id, let state):
                    installStates[id] = state
                case .progress(let id, let progress):
                    installStates[id] = .downloading(progress: progress)
                case .completed(let record):
                    installStates[record.descriptor.id] = record.installState
                    upsert(record)
                case .failed(let id, let error):
                    installStates[id] = .failed(String(describing: error))
                }
            }
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    private func upsert(_ record: InstalledModelRecord) {
        if let index = models.firstIndex(where: { $0.descriptor.id == record.descriptor.id }) {
            models[index] = record
        } else {
            models.append(record)
        }
    }
}

public enum LLMUIDownloadsNamespace {}
