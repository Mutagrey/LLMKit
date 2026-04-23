import Foundation

public struct ToolCallID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static func generated() -> ToolCallID {
        ToolCallID(UUID().uuidString)
    }
}
