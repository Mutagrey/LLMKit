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

    public init(models: [InstalledModelRecord] = []) {
        self.models = models
    }

    public func replaceModels(_ models: [InstalledModelRecord]) {
        self.models = models
    }
}

public enum LLMUIDownloadsNamespace {}
