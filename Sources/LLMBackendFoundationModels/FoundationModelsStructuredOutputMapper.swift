import Foundation
import LLMCore

#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
import FoundationModels
#endif

enum FoundationModelsStructuredOutputMapper {
    static func plan(for schema: StructuredOutputSchema) throws -> StructuredSchemaPlan {
        try StructuredSchemaPlan(
            rootName: schema.name.flatMap(Self.sanitizedName(_:)) ?? "StructuredOutput",
            rootNode: parseSchemaObject(schema.definition, at: "root")
        )
    }

    private static func parseSchemaObject(_ object: [String: ToolValue], at path: String) throws -> StructuredSchemaNode {
        if let enumValues = enumValues(in: object) {
            return .stringEnum(enumValues)
        }

        if let anyOf = object["anyOf"] {
            guard case .array(let values) = anyOf else {
                throw BackendError.mappingFailed("Foundation Models anyOf schema at \(path) must be an array.")
            }
            return .anyOf(try values.enumerated().map { index, value in
                guard case .object(let schemaObject) = value else {
                    throw BackendError.mappingFailed("Foundation Models anyOf schema at \(path)[\(index)] must be an object.")
                }
                return try parseSchemaObject(schemaObject, at: "\(path).anyOf[\(index)]")
            })
        }

        guard let type = typeName(in: object) else {
            throw BackendError.mappingFailed("Foundation Models schema at \(path) is missing a supported type.")
        }

        switch type {
        case "object":
            let required = requiredKeys(in: object)
            guard let propertiesValue = object["properties"] else {
                throw BackendError.mappingFailed("Foundation Models object schema at \(path) is missing properties.")
            }
            guard case .object(let propertiesObject) = propertiesValue else {
                throw BackendError.mappingFailed("Foundation Models object schema at \(path).properties must be an object.")
            }
            let properties = try propertiesObject
                .sorted { $0.key < $1.key }
                .map { key, value in
                    guard case .object(let propertyObject) = value else {
                        throw BackendError.mappingFailed("Foundation Models property schema at \(path).\(key) must be an object.")
                    }
                    return StructuredSchemaProperty(
                        name: key,
                        isOptional: !required.contains(key),
                        node: try parseSchemaObject(propertyObject, at: "\(path).\(key)")
                    )
                }
            return .object(properties)

        case "array":
            guard let itemsValue = object["items"] else {
                throw BackendError.mappingFailed("Foundation Models array schema at \(path) is missing items.")
            }
            guard case .object(let itemsObject) = itemsValue else {
                throw BackendError.mappingFailed("Foundation Models array schema at \(path).items must be an object.")
            }
            return .array(try parseSchemaObject(itemsObject, at: "\(path).items"))

        case "string":
            return .string
        case "integer":
            return .integer
        case "number":
            return .number
        case "boolean":
            return .boolean
        case "null":
            throw BackendError.mappingFailed("Foundation Models native structured output does not support null schema nodes in this adapter yet.")
        default:
            throw BackendError.mappingFailed("Foundation Models schema type '\(type)' at \(path) is unsupported.")
        }
    }

    private static func enumValues(in object: [String: ToolValue]) -> [String]? {
        guard let enumValue = object["enum"] else {
            return nil
        }
        guard case .array(let values) = enumValue else {
            return nil
        }
        let strings = values.compactMap { value -> String? in
            guard case .string(let string) = value else {
                return nil
            }
            return string
        }
        return strings.count == values.count && !strings.isEmpty ? strings : nil
    }

    private static func typeName(in object: [String: ToolValue]) -> String? {
        guard case .string(let type)? = object["type"] else {
            return nil
        }
        return type
    }

    private static func requiredKeys(in object: [String: ToolValue]) -> Set<String> {
        guard case .array(let values)? = object["required"] else {
            return []
        }
        return Set(values.compactMap { value in
            guard case .string(let key) = value else {
                return nil
            }
            return key
        })
    }

    private static func sanitizedName(_ name: String) -> String? {
        let filteredScalars = name.unicodeScalars.map { scalar -> UnicodeScalar in
            switch scalar.value {
            case 48...57, 65...90, 95, 97...122:
                return scalar
            default:
                return "_"
            }
        }
        let sanitized = String(String.UnicodeScalarView(filteredScalars)).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return sanitized.isEmpty ? nil : String(sanitized.prefix(64))
    }
}

struct StructuredSchemaPlan: Equatable, Sendable {
    let rootName: String
    let rootNode: StructuredSchemaNode
}

indirect enum StructuredSchemaNode: Equatable, Sendable {
    case object([StructuredSchemaProperty])
    case array(StructuredSchemaNode)
    case string
    case stringEnum([String])
    case integer
    case number
    case boolean
    case anyOf([StructuredSchemaNode])
}

struct StructuredSchemaProperty: Equatable, Sendable {
    let name: String
    let isOptional: Bool
    let node: StructuredSchemaNode
}

#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
extension FoundationModelsStructuredOutputMapper {
    static func generationSchema(for schema: StructuredOutputSchema) throws -> GenerationSchema {
        let plan = try plan(for: schema)
        let root = try dynamicSchema(for: plan.rootNode, name: plan.rootName)
        return try GenerationSchema(root: root, dependencies: [])
    }

    private static func dynamicSchema(for node: StructuredSchemaNode, name: String) throws -> DynamicGenerationSchema {
        switch node {
        case .object(let properties):
            return DynamicGenerationSchema(
                name: name,
                properties: try properties.map { property in
                    .init(
                        name: property.name,
                        schema: try dynamicSchema(
                            for: property.node,
                            name: nestedName(parent: name, property: property.name)
                        ),
                        isOptional: property.isOptional
                    )
                }
            )
        case .array(let item):
            return DynamicGenerationSchema(arrayOf: try dynamicSchema(for: item, name: "\(name)_Item"))
        case .string:
            return DynamicGenerationSchema(type: String.self)
        case .stringEnum(let values):
            return DynamicGenerationSchema(name: name, anyOf: values)
        case .integer:
            return DynamicGenerationSchema(type: Int.self)
        case .number:
            return DynamicGenerationSchema(type: Double.self)
        case .boolean:
            return DynamicGenerationSchema(type: Bool.self)
        case .anyOf(let choices):
            return DynamicGenerationSchema(name: name, anyOf: try choices.enumerated().map { index, choice in
                try dynamicSchema(for: choice, name: "\(name)_Option\(index)")
            })
        }
    }

    private static func nestedName(parent: String, property: String) -> String {
        let fragment = sanitizedName(property) ?? "Field"
        return "\(parent)_\(fragment)"
    }
}
#endif
