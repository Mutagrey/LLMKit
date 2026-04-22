import Foundation

public enum StreamFinishReason: Hashable, Codable, Sendable {
    case completed
    case stopped
    case lengthLimit
    case toolCall
    case cancelled
}
