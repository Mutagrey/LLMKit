import Foundation

public enum ToolValue: Hashable, Sendable {
    case string(String)
    case integer(Int)
    case number(Double)
    case boolean(Bool)
    case array([ToolValue])
    case object([String: ToolValue])
    case null

    public var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .integer(let value):
            return String(value)
        case .number(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .array, .object:
            return jsonString ?? ""
        case .null:
            return "null"
        }
    }

    private var jsonString: String? {
        guard
            let data = try? JSONEncoder().encode(self),
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }
}

extension ToolValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([ToolValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: ToolValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported tool value.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
