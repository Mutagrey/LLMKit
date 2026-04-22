import Foundation

public enum AvailabilityStatus: Hashable, Codable, Sendable {
    case available
    case unavailable(reason: String)
    case requiresInstall
    case requiresNetwork
    case unsupported
}
