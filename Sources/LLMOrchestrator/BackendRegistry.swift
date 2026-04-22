import LLMCore
import LLMProtocols

public actor BackendRegistry {
    private var backends: [BackendKind: any ModelBackend]

    public init(backends: [any ModelBackend] = []) {
        self.backends = Dictionary(uniqueKeysWithValues: backends.map { ($0.backendKind, $0) })
    }

    public func register(_ backend: any ModelBackend) {
        backends[backend.backendKind] = backend
    }

    public func backend(for kind: BackendKind) -> (any ModelBackend)? {
        backends[kind]
    }

    public func allBackends() -> [any ModelBackend] {
        Array(backends.values)
    }
}
