import Foundation
import LLMCore

public struct PromptTemplateID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public struct PromptVersion: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PromptFragment: Hashable, Codable, Sendable {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }
}

public struct PromptTemplate: Hashable, Codable, Sendable, Identifiable {
    public let id: PromptTemplateID
    public let version: PromptVersion
    public let fragments: [PromptFragment]

    public init(id: PromptTemplateID, version: PromptVersion, fragments: [PromptFragment]) {
        self.id = id
        self.version = version
        self.fragments = fragments
    }
}

public struct PromptContext: Hashable, Sendable {
    public let messages: [ChatMessage]
    public let variables: [String: String]

    public init(messages: [ChatMessage] = [], variables: [String: String] = [:]) {
        self.messages = messages
        self.variables = variables
    }
}

public struct PromptDebugSnapshot: Hashable, Sendable {
    public let templateID: PromptTemplateID
    public let assembledPrompt: String

    public init(templateID: PromptTemplateID, assembledPrompt: String) {
        self.templateID = templateID
        self.assembledPrompt = assembledPrompt
    }
}
