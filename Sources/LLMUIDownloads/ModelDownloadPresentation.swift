import LLMCore

extension ModelDownloadsViewModel {
    public func installState(for modelID: ModelID) -> InstallState {
        installStates[modelID] ?? .notInstalled
    }
}
