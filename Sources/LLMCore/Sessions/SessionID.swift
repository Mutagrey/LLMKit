import Foundation

public struct SessionID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static func generated() -> SessionID {
        SessionID(rawValue: UUID().uuidString)
    }

    public var description: String {
        rawValue
    }
}
