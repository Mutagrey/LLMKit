import LLMCore

public struct LoadedModelHandle: Hashable, Sendable, Identifiable {
    public let id: ModelID
    public let backend: BackendKind

    public init(id: ModelID, backend: BackendKind) {
        self.id = id
        self.backend = backend
    }
}
