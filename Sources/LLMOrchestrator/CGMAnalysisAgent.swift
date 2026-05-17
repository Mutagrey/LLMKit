import LLMCore
import LLMProtocols

public struct CGMAnalysisRequest: Hashable, Sendable {
    public let metricsSummary: String
    public let userContextSummary: String?
    public let recentObservations: String?
    public let userQuestion: String?

    public init(
        metricsSummary: String,
        userContextSummary: String? = nil,
        recentObservations: String? = nil,
        userQuestion: String? = nil
    ) {
        self.metricsSummary = metricsSummary
        self.userContextSummary = userContextSummary
        self.recentObservations = recentObservations
        self.userQuestion = userQuestion
    }
}

public struct CGMAnalysisAgent: Sendable {
    public let sessionID: SessionID
    private let chat: any ChatService
    private let requirements: ExecutionRequirements

    public init(
        chat: any ChatService,
        sessionID: SessionID = .generated(),
        requirements: ExecutionRequirements = ExecutionRequirements(
            requiredCapabilities: [.chat],
            executionMode: .offlineOnly,
            preferredLatency: .interactive,
            privacyMode: .localOnly,
            budget: ExecutionBudget(maxOutputTokens: 768)
        )
    ) {
        self.chat = chat
        self.sessionID = sessionID
        self.requirements = requirements
    }

    public func analyze(_ request: CGMAnalysisRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        chat.send(ChatRequest(
            messages: [
                ChatMessage(role: .system, content: MessageContent(text: systemPrompt)),
                ChatMessage(role: .user, content: MessageContent(text: userPrompt(for: request)))
            ],
            requirements: requirements,
            sessionID: sessionID
        ))
    }

    private var systemPrompt: String {
        [
            "You analyze CGM context from deterministic metrics computed by the host app.",
            "Do not diagnose, prescribe, or change therapy. Do not invent missing measurements.",
            "Explain patterns, uncertainty, and practical questions the user may want to discuss with a clinician.",
            "Ask concise follow-up questions when the provided context is insufficient."
        ].joined(separator: " ")
    }

    private func userPrompt(for request: CGMAnalysisRequest) -> String {
        [
            section("CGM metrics", request.metricsSummary),
            section("User context", request.userContextSummary ?? "None."),
            section("Recent observations", request.recentObservations ?? "None."),
            section("User question", request.userQuestion ?? "No explicit question.")
        ].joined(separator: "\n\n")
    }

    private func section(_ title: String, _ value: String) -> String {
        "\(title):\n\(value)"
    }
}
