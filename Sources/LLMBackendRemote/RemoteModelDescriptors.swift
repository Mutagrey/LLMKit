import Foundation
import LLMCore

public enum RemoteModelDescriptors {
    public static func openAIChatCompletions(
        id: ModelID,
        displayName: String? = nil,
        contextWindowTokens: Int? = nil,
        supportsTools: Bool = false,
        supportsStructuredOutput: Bool = false,
        extraCapabilities: Set<ModelCapability> = [],
        tags: [String] = []
    ) -> ModelDescriptor {
        remoteDescriptor(
            id: id,
            displayName: displayName,
            family: .custom("openai"),
            contextWindowTokens: contextWindowTokens,
            supportsTools: supportsTools,
            supportsStructuredOutput: supportsStructuredOutput,
            extraCapabilities: extraCapabilities,
            tags: ["provider:openai", "api:chat-completions"] + tags
        )
    }

    public static func openAIResponses(
        id: ModelID,
        displayName: String? = nil,
        contextWindowTokens: Int? = nil,
        supportsTools: Bool = false,
        supportsStructuredOutput: Bool = false,
        extraCapabilities: Set<ModelCapability> = [],
        tags: [String] = []
    ) -> ModelDescriptor {
        remoteDescriptor(
            id: id,
            displayName: displayName,
            family: .custom("openai"),
            contextWindowTokens: contextWindowTokens,
            supportsTools: supportsTools,
            supportsStructuredOutput: supportsStructuredOutput,
            extraCapabilities: extraCapabilities,
            tags: ["provider:openai", "api:responses"] + tags
        )
    }

    public static func anthropicMessages(
        id: ModelID,
        displayName: String? = nil,
        contextWindowTokens: Int? = nil,
        supportsTools: Bool = false,
        extraCapabilities: Set<ModelCapability> = [],
        tags: [String] = []
    ) -> ModelDescriptor {
        remoteDescriptor(
            id: id,
            displayName: displayName,
            family: .custom("anthropic"),
            contextWindowTokens: contextWindowTokens,
            supportsTools: supportsTools,
            supportsStructuredOutput: false,
            extraCapabilities: extraCapabilities,
            tags: ["provider:anthropic", "api:messages"] + tags
        )
    }

    private static func remoteDescriptor(
        id: ModelID,
        displayName: String?,
        family: ModelFamily,
        contextWindowTokens: Int?,
        supportsTools: Bool,
        supportsStructuredOutput: Bool,
        extraCapabilities: Set<ModelCapability>,
        tags: [String]
    ) -> ModelDescriptor {
        var capabilities: Set<ModelCapability> = [
            .chat,
            .completion,
            .streaming
        ]
        if supportsTools {
            capabilities.insert(.toolCalling)
        }
        if supportsStructuredOutput {
            capabilities.insert(.structuredOutput)
        }
        capabilities.formUnion(extraCapabilities)

        return ModelDescriptor(
            id: id,
            displayName: displayName ?? id.rawValue,
            family: family,
            backend: .remote,
            capabilities: capabilities,
            contextWindowTokens: contextWindowTokens,
            supportsStreaming: true,
            supportsTools: supportsTools,
            supportsStructuredOutput: supportsStructuredOutput,
            isRemote: true,
            tags: tags
        )
    }
}
