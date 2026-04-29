import Foundation
import LLMCore
import LLMProtocols

public actor SessionFileStore: SessionStore {
    private let paths: StoragePaths
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let writeCoordinator: AtomicWriteCoordinator

    public init(
        paths: StoragePaths,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        writeCoordinator: AtomicWriteCoordinator = AtomicWriteCoordinator()
    ) {
        self.paths = paths
        self.encoder = encoder
        self.decoder = decoder
        self.writeCoordinator = writeCoordinator
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func listSessions() async throws -> [SessionOverview] {
        guard FileManager.default.fileExists(atPath: paths.sessionIndexURL.path) else {
            return try rebuildIndexFromSnapshots()
        }
        let data = try Data(contentsOf: paths.sessionIndexURL)
        return try decoder.decode([SessionOverview].self, from: data)
    }

    public func loadSession(id: SessionID) async throws -> SessionSnapshot? {
        let url = paths.sessionURL(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(SessionSnapshot.self, from: data)
    }

    public func saveSession(_ snapshot: SessionSnapshot) async throws {
        let data = try encoder.encode(snapshot)
        try writeCoordinator.write(data, to: paths.sessionURL(id: snapshot.id))

        var overviews = try await listSessions()
        overviews.removeAll { $0.id == snapshot.id }
        overviews.append(snapshot.overview)
        overviews.sort { $0.updatedAt > $1.updatedAt }
        try writeCoordinator.write(try encoder.encode(overviews), to: paths.sessionIndexURL)
    }

    public func deleteSession(id: SessionID) async throws {
        let url = paths.sessionURL(id: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        var overviews = try await listSessions()
        overviews.removeAll { $0.id == id }
        if overviews.isEmpty {
            if FileManager.default.fileExists(atPath: paths.sessionIndexURL.path) {
                try FileManager.default.removeItem(at: paths.sessionIndexURL)
            }
        } else {
            try writeCoordinator.write(try encoder.encode(overviews), to: paths.sessionIndexURL)
        }
    }

    private func rebuildIndexFromSnapshots() throws -> [SessionOverview] {
        guard FileManager.default.fileExists(atPath: paths.sessionsDirectory.path) else {
            return []
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: paths.sessionsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let snapshots = try urls
            .filter { $0.lastPathComponent != paths.sessionIndexURL.lastPathComponent && $0.pathExtension == "json" }
            .map { try decoder.decode(SessionSnapshot.self, from: Data(contentsOf: $0)) }
        let overviews = snapshots.map(\.overview).sorted { $0.updatedAt > $1.updatedAt }
        if !overviews.isEmpty {
            try writeCoordinator.write(try encoder.encode(overviews), to: paths.sessionIndexURL)
        }
        return overviews
    }
}
