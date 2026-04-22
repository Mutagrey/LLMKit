import Foundation

public struct TraceID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static func generated() -> TraceID {
        TraceID(rawValue: UUID().uuidString)
    }
}

public struct TelemetryEvent: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let traceID: TraceID?
    public let name: String
    public let metadata: [String: String]
    public let createdAt: Date

    public init(id: UUID = UUID(), traceID: TraceID? = nil, name: String, metadata: [String: String] = [:], createdAt: Date = Date()) {
        self.id = id
        self.traceID = traceID
        self.name = name
        self.metadata = metadata
        self.createdAt = createdAt
    }
}
