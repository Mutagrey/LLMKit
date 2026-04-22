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

    public func createSession(title: String? = nil) async -> SessionSnapshot {
        let id = SessionID.generated()
        let descriptor = SessionDescriptor(id: id, title: title)
        let snapshot = SessionSnapshot(id: id, descriptor: descriptor)
        snapshots[id] = snapshot
        try? await store?.saveSession(snapshot)
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

    public func append(_ message: ChatMessage, to sessionID: SessionID) async throws -> SessionSnapshot {
        let existing = try await loadSession(id: sessionID) ?? SessionSnapshot(
            id: sessionID,
            descriptor: SessionDescriptor(id: sessionID)
        )
        let descriptor = SessionDescriptor(
            id: existing.id,
            title: existing.descriptor.title,
            createdAt: existing.descriptor.createdAt,
            updatedAt: Date()
        )
        let updated = SessionSnapshot(
            id: existing.id,
            descriptor: descriptor,
            messages: existing.messages + [message],
            summary: existing.summary
        )
        snapshots[sessionID] = updated
        try await store?.saveSession(updated)
        return updated
    }
}
