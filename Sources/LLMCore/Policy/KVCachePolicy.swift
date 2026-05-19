import Foundation

public enum KVCachePolicy: String, Hashable, Codable, Sendable {
    case safeF16
    case q8Experimental
    case q4Experimental
    case runtimeDefault

    public static let defaultPolicy: KVCachePolicy = .runtimeDefault

    public var isExperimental: Bool {
        switch self {
        case .q8Experimental, .q4Experimental:
            true
        case .safeF16, .runtimeDefault:
            false
        }
    }

    public var requiresQuantizedKVCacheSupport: Bool {
        switch self {
        case .q8Experimental, .q4Experimental:
            true
        case .safeF16, .runtimeDefault:
            false
        }
    }

    public func resolved(supportsQuantizedKVCache: Bool) -> KVCachePolicy {
        guard requiresQuantizedKVCacheSupport, !supportsQuantizedKVCache else {
            return self
        }
        return .runtimeDefault
    }
}
