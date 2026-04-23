import Foundation

public struct RemoteConfiguration: Hashable, Sendable {
    public let providerID: RemoteProviderID
    public let baseURL: URL
    public let defaultHeaders: [String: String]
    public let generationPath: String
    public let chatPath: String
    public let apiStyle: RemoteAPIStyle

    public init(
        providerID: RemoteProviderID,
        baseURL: URL,
        defaultHeaders: [String: String] = [:],
        generationPath: String = "completions",
        chatPath: String = "chat/completions",
        apiStyle: RemoteAPIStyle = .genericCompletionsAndChat
    ) {
        self.providerID = providerID
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.generationPath = generationPath
        self.chatPath = chatPath
        self.apiStyle = apiStyle
    }
}

public extension RemoteConfiguration {
    static func openAI(
        apiKey: String,
        organizationID: String? = nil,
        projectID: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
    ) -> RemoteConfiguration {
        var headers = [
            "Authorization": "Bearer \(apiKey)"
        ]
        if let organizationID {
            headers["OpenAI-Organization"] = organizationID
        }
        if let projectID {
            headers["OpenAI-Project"] = projectID
        }
        return RemoteConfiguration(
            providerID: "openai",
            baseURL: baseURL,
            defaultHeaders: headers,
            generationPath: "chat/completions",
            chatPath: "chat/completions",
            apiStyle: .openAIChatCompletions
        )
    }
}
