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
                providerMessages.append(AnthropicMessage(role: message.role.rawValue, content: .text(message.content.text)))
            case .tool:
                guard let reference = message.toolCallReference else {
                    throw BackendError.mappingFailed("Anthropic tool messages require a tool call reference.")
                }
                providerMessages.append(AnthropicMessage(
                    role: MessageRole.user.rawValue,
                    content: .blocks([
                        .toolResult(toolUseID: reference.id.rawValue, content: message.content.text)
                    ])
                ))
            }
        }

        return AnthropicMessageMapping(
            messages: providerMessages,
            system: systemParts.isEmpty ? nil : systemParts.joined(separator: "\n\n")
        )
    }
}
