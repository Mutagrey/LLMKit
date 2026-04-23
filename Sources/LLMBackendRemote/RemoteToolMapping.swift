import Foundation
import LLMCore

struct OpenAIChatTool: Encodable {
    let type = "function"
    let function: OpenAIChatToolFunction
}

struct OpenAIChatToolFunction: Encodable {
    let name: String
    let description: String
    let parameters: RemoteToolParameters
}

struct OpenAIResponsesTool: Encodable {
    let type = "function"
    let name: String
    let description: String
    let parameters: RemoteToolParameters
}

struct AnthropicTool: Encodable {
    let name: String
    let description: String
    let inputSchema: RemoteToolParameters

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
}

struct RemoteToolParameters: Encodable {
    let type = "object"
    let properties: [String: RemoteToolParameterSchema]
    let required: [String]
}

struct RemoteToolParameterSchema: Encodable {
    let description: String?
}

enum RemoteToolDefinitionMapper {
    static func openAIChatTools(from definitions: [ToolDefinition]) -> [OpenAIChatTool]? {
        let tools = definitions.map {
            OpenAIChatTool(function: OpenAIChatToolFunction(
                name: $0.name,
                description: $0.description,
                parameters: parameters(for: $0.schema)
            ))
        }
        return tools.isEmpty ? nil : tools
    }

    static func openAIResponsesTools(from definitions: [ToolDefinition]) -> [OpenAIResponsesTool]? {
        let tools = definitions.map {
            OpenAIResponsesTool(
                name: $0.name,
                description: $0.description,
                parameters: parameters(for: $0.schema)
            )
        }
        return tools.isEmpty ? nil : tools
    }

    static func anthropicTools(from definitions: [ToolDefinition]) -> [AnthropicTool]? {
        let tools = definitions.map {
            AnthropicTool(
                name: $0.name,
                description: $0.description,
                inputSchema: parameters(for: $0.schema)
            )
        }
        return tools.isEmpty ? nil : tools
    }

    private static func parameters(for schema: ToolSchema) -> RemoteToolParameters {
        let allNames = Set(schema.requiredArguments).union(schema.argumentDescriptions.keys)
        let properties = Dictionary(uniqueKeysWithValues: allNames.map { name in
            (name, RemoteToolParameterSchema(description: schema.argumentDescriptions[name]))
        })
        return RemoteToolParameters(
            properties: properties,
            required: schema.requiredArguments.sorted()
        )
    }
}

enum RemoteToolInvocationMapper {
    static func invocation(callID: String?, fallbackID: String?, toolName: String?, argumentsJSON: String?) throws -> ToolInvocation? {
        guard let toolName else {
            return nil
        }
        let resolvedID = callID ?? fallbackID ?? ToolCallID.generated().rawValue
        return ToolInvocation(
            id: ToolCallID(resolvedID),
            toolName: toolName,
            arguments: try arguments(from: argumentsJSON)
        )
    }

    static func invocation(callID: String?, fallbackID: String?, toolName: String?, inputObject: [String: ToolValue]?) -> ToolInvocation? {
        guard let toolName else {
            return nil
        }
        let resolvedID = callID ?? fallbackID ?? ToolCallID.generated().rawValue
        return ToolInvocation(
            id: ToolCallID(resolvedID),
            toolName: toolName,
            arguments: ToolArguments(structuredValues: inputObject ?? [:])
        )
    }

    private static func arguments(from json: String?) throws -> ToolArguments {
        guard let json, !json.isEmpty else {
            return ToolArguments()
        }
        let data = Data(json.utf8)
        let object = try JSONDecoder().decode([String: ToolValue].self, from: data)
        return ToolArguments(structuredValues: object)
    }
}
