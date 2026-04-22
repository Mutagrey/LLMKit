import Foundation

public enum BackendKind: Hashable, Codable, Sendable {
    case foundationModels
    case coreML
    case mlx
    case remote
    case executorch
    case onnxRuntime
    case custom(String)
}
