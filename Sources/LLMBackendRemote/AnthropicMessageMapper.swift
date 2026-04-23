import Foundation
import LLMCore

struct AnthropicMessageMapping {
    let messages: [AnthropicMessage]
    let system: String?
}

enum AnthropicMessageMapper {
    static func map(_ messages: [ChatMessage]) throws -> AnthropicMessageMapping {
        var providerMessages: [AnthropicMessage] = []
        var systemParts: [String] = []

        for message in messages {
            switch message.role {
            case .system, .developer:
                systemParts.append(message.content.text)
            case .user, .assistant:
                providerMessages.append(AnthropicMessage(role: message.role.rawValue, content: message.content.text))
            case .tool:
                throw BackendError.mappingFailed("Anthropic Messages mapping does not support tool role messages yet.")
            }
        }

        return AnthropicMessageMapping(
            messages: providerMessages,
            system: systemParts.isEmpty ? nil : systemParts.joined(separator: "\n\n")
        )
    }
}
