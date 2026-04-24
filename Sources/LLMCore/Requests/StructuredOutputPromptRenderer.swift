import Foundation

enum StructuredOutputPromptRenderer {
    static func render(prompt: String, schema: StructuredOutputSchema?) -> String {
        guard let schema, let schemaJSON = schema.jsonString else {
            return prompt
        }

        var lines = [prompt]
        lines.append("Return only valid JSON with no surrounding commentary or code fences.")
        if let name = schema.name, !name.isEmpty {
            lines.append("Schema name: \(name)")
        }
        lines.append("JSON schema:")
        lines.append(schemaJSON)
        return lines.joined(separator: "\n\n")
    }
}
