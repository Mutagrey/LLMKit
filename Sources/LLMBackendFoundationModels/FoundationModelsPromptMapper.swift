import Foundation
import LLMCore

package struct FoundationModelsMappedChatPrompt: Sendable, Equatable {
    package let instructions: String?
    package let prompt: String
}

package enum FoundationModelsPromptMapper {
    package static func prompt(for request: ChatRequest) -> FoundationModelsMappedChatPrompt {
        var instructionLines: [String] = []
        var promptLines: [String] = []

        if let toolInstructions = toolInstructions(for: request.tools) {
            instructionLines.append(toolInstructions)
        }

        for message in request.messages {
            let text = message.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                continue
            }

            switch message.role {
            case .system:
                instructionLines.append(text)
            case .developer:
                instructionLines.append("Developer: \(text)")
            case .user:
                promptLines.append("User: \(text)")
            case .assistant:
                promptLines.append("Assistant: \(text)")
            case .tool:
                promptLines.append(toolResultLine(for: message, text: text))
            }
        }

        return FoundationModelsMappedChatPrompt(
            instructions: instructionLines.isEmpty ? nil : instructionLines.joined(separator: "\n\n"),
            prompt: promptLines.isEmpty ? "" : promptLines.joined(separator: "\n\n")
        )
    }

    private static func toolInstructions(for tools: [ToolDefinition]) -> String? {
        guard !tools.isEmpty else {
            return nil
        }

        let lines = tools.sorted { $0.name < $1.name }.map { definition in
            var segments: [String] = []
            segments.append("- \(definition.name): \(definition.description)")
            if !definition.schema.requiredArguments.isEmpty {
                segments.append("required=\(definition.schema.requiredArguments.sorted().joined(separator: ", "))")
            }
            if !definition.schema.argumentDescriptions.isEmpty {
                let argumentDescriptions = definition.schema.argumentDescriptions
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: "; ")
                segments.append("arguments=\(argumentDescriptions)")
            }
            return segments.joined(separator: " | ")
        }

        return """
        Available Tools:
        \(lines.joined(separator: "\n"))
        """
    }

    private static func toolResultLine(for message: ChatMessage, text: String) -> String {
        guard let reference = message.toolCallReference else {
            return "Tool: \(text)"
        }
        return "Tool[\(reference.toolName)#\(reference.id.rawValue)]: \(text)"
    }
}
