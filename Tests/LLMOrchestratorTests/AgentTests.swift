import Foundation
import LLMCore
import LLMOrchestrator
import LLMProtocols
import Testing

private struct TestUserProfile: Codable, Equatable, Sendable {
    let prefersEarlyMeals: Bool
}

private final class RecordingStructuredService: StructuredGenerationService, @unchecked Sendable {
    private let state = State()

    func generate<T: Decodable & Sendable>(_ type: T.Type, request: StructuredRequest) async throws -> T {
        await state.record(request)
        let data = Data(#"{"prefersEarlyMeals":true}"#.utf8)
        return try JSONDecoder().decode(type, from: data)
    }

    func recordedRequests() async -> [StructuredRequest] {
        await state.snapshot()
    }

    private actor State {
        private var requests: [StructuredRequest] = []

        func record(_ request: StructuredRequest) {
            requests.append(request)
        }

        func snapshot() -> [StructuredRequest] {
            requests
        }
    }
}

private final class RecordingChatService: ChatService, @unchecked Sendable {
    private let state = State()

    func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await state.record(request)
                continuation.yield(.completed(ChatResult(
                    message: ChatMessage(role: .assistant, content: MessageContent(text: "analysis"))
                )))
                continuation.finish()
            }
        }
    }

    func recordedRequests() async -> [ChatRequest] {
        await state.snapshot()
    }

    private actor State {
        private var requests: [ChatRequest] = []

        func record(_ request: ChatRequest) {
            requests.append(request)
        }

        func snapshot() -> [ChatRequest] {
            requests
        }
    }
}

@Test func cgmAgentsUseSeparateSessionIdentifiers() async throws {
    let structured = RecordingStructuredService()
    let chat = RecordingChatService()
    let extractor = UserInfoExtractorAgent(structured: structured, sessionID: "user-memory-agent")
    let analyzer = CGMAnalysisAgent(chat: chat, sessionID: "cgm-analysis-agent")
    let schema = StructuredOutputSchema(name: "UserProfile", definition: [
        "type": .string("object"),
        "properties": .object([
            "prefersEarlyMeals": .object(["type": .string("boolean")])
        ])
    ])

    async let profile = extractor.extract(
        TestUserProfile.self,
        from: "I usually eat breakfast before 7 AM.",
        schema: schema
    )
    async let events = collect(analyzer.analyze(CGMAnalysisRequest(
        metricsSummary: "time in range: 82%; overnight lows: none",
        userContextSummary: "Usually eats breakfast before 7 AM."
    )))

    let resolvedProfile = try await profile
    let resolvedEvents = try await events
    let structuredRequests = await structured.recordedRequests()
    let chatRequests = await chat.recordedRequests()

    #expect(resolvedProfile == TestUserProfile(prefersEarlyMeals: true))
    #expect(resolvedEvents.contains { event in
        if case .completed = event {
            return true
        }
        return false
    })
    #expect(structuredRequests.first?.sessionID == "user-memory-agent")
    #expect(chatRequests.first?.sessionID == "cgm-analysis-agent")
    #expect(chatRequests.first?.messages.first?.role == .system)
    #expect(chatRequests.first?.messages.last?.content.text.contains("time in range") == true)
}

private func collect(_ stream: AsyncThrowingStream<ChatEvent, Error>) async throws -> [ChatEvent] {
    var events: [ChatEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}
