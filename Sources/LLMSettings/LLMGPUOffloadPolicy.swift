import Foundation

public enum LLMGPUOffloadPolicy: Hashable, Codable, Sendable {
    case automatic
    case disabled
    case custom(layerCount: Int)

    public var requestedLayerCount: Int {
        switch self {
        case .automatic:
            return 99
        case .disabled:
            return 0
        case .custom(let layerCount):
            return max(0, layerCount)
        }
    }

    public var usesMetal: Bool {
        switch self {
        case .automatic, .custom:
            return true
        case .disabled:
            return false
        }
    }
}
