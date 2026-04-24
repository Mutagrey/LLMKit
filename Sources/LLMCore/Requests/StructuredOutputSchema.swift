import Foundation

public struct StructuredOutputSchema: Hashable, Codable, Sendable {
    public let name: String?
    public let definition: [String: ToolValue]

    public init(name: String? = nil, definition: [String: ToolValue]) {
        self.name = name
        self.definition = definition
    }

    public var jsonValue: ToolValue {
        .object(definition)
    }

    public var jsonString: String? {
        guard
            let data = try? JSONEncoder().encode(jsonValue),
            let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }
}
