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
        self._viewModel = State(initialValue: ModelDownloadsViewModel(models: models, lifecycleService: lifecycleService))
        self.configuredDescriptors = descriptors
    }

    public var body: some View {
        List(visibleDescriptors, id: \.id) { descriptor in
            ModelDownloadCardView(
                descriptor: descriptor,
                state: viewModel.installState(for: descriptor.id),
                isInstallButtonDisabled: viewModel.isInstallButtonDisabled(for: descriptor.id)
            ) {
                await viewModel.install(descriptor)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
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
            await viewModel.refresh()
        }
    }

    private var visibleDescriptors: [ModelDescriptor] {
        var seen = Set<ModelID>()
        return (configuredDescriptors + viewModel.models.map(\.descriptor)).filter { descriptor in
            seen.insert(descriptor.id).inserted
        }
    }
}

@MainActor
@Observable
public final class ModelDownloadsViewModel {
    public private(set) var models: [InstalledModelRecord]
    public private(set) var installStates: [ModelID: InstallState]
    public private(set) var installingModelIDs: Set<ModelID>
    public private(set) var lastErrorMessage: String?
    @ObservationIgnored
    private let lifecycleService: (any ModelLifecycleService)?

    public init(models: [InstalledModelRecord] = [], lifecycleService: (any ModelLifecycleService)? = nil) {
        self.models = models
        self.installStates = Dictionary(uniqueKeysWithValues: models.map { ($0.descriptor.id, $0.installState) })
        self.installingModelIDs = []
        self.lifecycleService = lifecycleService
    }

    public func replaceModels(_ models: [InstalledModelRecord]) {
        self.models = models
        self.installStates = Dictionary(uniqueKeysWithValues: models.map { ($0.descriptor.id, $0.installState) })
    }

    public func refresh() async {
        guard let lifecycleService else {
            return
        }
        lastErrorMessage = nil
        do {
            replaceModels(try await lifecycleService.installedModels())
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
                case .completed(let record):
                    installStates[record.descriptor.id] = record.installState
                    installingModelIDs.remove(record.descriptor.id)
                    upsert(record)
                case .failed(let id, let error):
                    installStates[id] = .failed(String(describing: error))
                    installingModelIDs.remove(id)
                }
            }
        } catch {
            lastErrorMessage = String(describing: error)
        }
        installingModelIDs.remove(descriptor.id)
    }

    public func statusText(for modelID: ModelID) -> String {
        switch installStates[modelID] ?? .notInstalled {
        case .notInstalled:
            return "Not installed"
        case .downloading(let progress):
            return "Downloading \(Int((progress * 100).rounded()))%"
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

    private func upsert(_ record: InstalledModelRecord) {
        if let index = models.firstIndex(where: { $0.descriptor.id == record.descriptor.id }) {
            models[index] = record
        } else {
            models.append(record)
        }
    }
}

public enum LLMUIDownloadsNamespace {}
