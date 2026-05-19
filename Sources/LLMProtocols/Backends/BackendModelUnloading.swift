public protocol BackendModelUnloading: Sendable {
    func unloadAllModels() async
}
