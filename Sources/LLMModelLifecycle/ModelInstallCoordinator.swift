import Foundation
import LLMCore
import LLMProtocols

public actor ModelInstallCoordinator: ModelLifecycleService, InstalledModelProviding {
    private var records: [ModelID: InstalledModelRecord]
    private let stateMachine: InstallStateMachine

    public init(records: [InstalledModelRecord] = [], stateMachine: InstallStateMachine = InstallStateMachine()) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.descriptor.id, $0) })
        self.stateMachine = stateMachine
    }

    public func installedModels() async throws -> [InstalledModelRecord] {
        Array(records.values).sorted { $0.descriptor.displayName < $1.descriptor.displayName }
    }

    public func installedRecord(for id: ModelID) async throws -> InstalledModelRecord? {
        records[id]
    }

    public func state(for modelID: ModelID) async throws -> InstallState {
        await stateMachine.state(for: modelID)
    }

    public nonisolated func install(_ descriptor: ModelDescriptor) -> AsyncThrowingStream<ModelInstallEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let record = await completeInstall(descriptor)
                continuation.yield(.stateChanged(descriptor.id, .ready))
                continuation.yield(.completed(record))
                continuation.finish()
            }
        }
    }

    private func completeInstall(_ descriptor: ModelDescriptor) async -> InstalledModelRecord {
        await stateMachine.transition(modelID: descriptor.id, to: .ready)
        let record = InstalledModelRecord(descriptor: descriptor, installState: .ready, installedAt: Date())
        records[descriptor.id] = record
        return record
    }
}
