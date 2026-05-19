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

    public func prepareForLocalModelExecution(_ model: ModelDescriptor) async {
        guard Self.isLocalRuntime(model.backend) else {
            return
        }

        for backend in backends.values where backend.backendKind != model.backend && Self.isLocalRuntime(backend.backendKind) {
            guard let unloading = backend as? any BackendModelUnloading else {
                continue
            }
            await unloading.unloadAllModels()
        }
    }

    private static func isLocalRuntime(_ backendKind: BackendKind) -> Bool {
        switch backendKind {
        case .coreML, .mlx, .llamaCpp:
            true
        case .foundationModels, .remote, .executorch, .onnxRuntime, .custom:
            false
        }
    }
}
