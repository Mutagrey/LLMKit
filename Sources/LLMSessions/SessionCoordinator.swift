import Foundation
import LLMCore
import LLMProtocols

public actor SessionCoordinator: SessionService {
    private var snapshots: [SessionID: SessionSnapshot]
    private let store: (any SessionStore)?

    public init(store: (any SessionStore)? = nil, initialSnapshots: [SessionSnapshot] = []) {
        self.store = store
        self.snapshots = Dictionary(uniqueKeysWithValues: initialSnapshots.map { ($0.id, $0) })
    }

    public func listSessions() async throws -> [SessionOverview] {
        var overviews = Dictionary(uniqueKeysWithValues: snapshots.values.map { ($0.id, $0.overview) })
        if let storedOverviews = try await store?.listSessions() {
            for overview in storedOverviews where overviews[overview.id] == nil {
                overviews[overview.id] = overview
            }
        }
        return overviews.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func createSession(
        title: String?,
        kind: SessionKind,
        executionRequirements: ExecutionRequirements?,
        automationDefinition: AutomatedConversationDefinition?,
        automationState: AutomatedConversationRunState?
    ) async throws -> SessionSnapshot {
        let id = SessionID.generated()
        let now = Date()
        let descriptor = SessionDescriptor(id: id, title: title, createdAt: now, updatedAt: now)
        let snapshot = SessionSnapshot(
            id: id,
            descriptor: descriptor,
            kind: kind,
            messages: [],
            summary: nil,
            executionRequirements: executionRequirements,
            automationDefinition: automationDefinition,
            automationState: automationState
        )
        snapshots[id] = snapshot
        try await store?.saveSession(snapshot)
        return snapshot
    }

    public func loadSession(id: SessionID) async throws -> SessionSnapshot? {
        if let snapshot = snapshots[id] {
            return snapshot
        }
        let loaded = try await store?.loadSession(id: id)
        if let loaded {
            snapshots[id] = loaded
        }
        return loaded
    }

    public func saveSession(_ snapshot: SessionSnapshot) async throws {
        snapshots[snapshot.id] = snapshot
        try await store?.saveSession(snapshot)
    }

    public func append(_ message: ChatMessage, to sessionID: SessionID) async throws -> SessionSnapshot {
        let existing = try await loadSession(id: sessionID) ?? SessionSnapshot(
            id: sessionID,
            descriptor: SessionDescriptor(id: sessionID)
        )
        let descriptor = SessionDescriptor(
            id: existing.id,
            title: resolvedTitle(for: existing, appending: message),
            createdAt: existing.descriptor.createdAt,
            updatedAt: Date()
        )
        let updated = SessionSnapshot(
            id: existing.id,
            descriptor: descriptor,
            kind: existing.kind,
            messages: existing.messages + [message],
            summary: existing.summary,
            executionRequirements: existing.executionRequirements,
            automationDefinition: existing.automationDefinition,
            automationState: existing.automationState
        )
        snapshots[sessionID] = updated
        try await store?.saveSession(updated)
        return updated
    }

    public func deleteSession(id: SessionID) async throws {
        snapshots[id] = nil
        try await store?.deleteSession(id: id)
    }

    private func resolvedTitle(for snapshot: SessionSnapshot, appending message: ChatMessage) -> String? {
        if let existingTitle = snapshot.descriptor.title, !existingTitle.isEmpty {
            return existingTitle
        }
        guard message.role == .user || snapshot.kind == .automatedConversation else {
            return snapshot.descriptor.title
        }
        let trimmed = message.content.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return snapshot.descriptor.title
        }
        return String(trimmed.prefix(60))
    }
}
