import Foundation
import LLMProtocols

public actor ManifestFileStore: ManifestStore {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func loadManifest(named name: String) async throws -> Data? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    public func saveManifest(_ data: Data, named name: String) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(name), options: [.atomic])
    }
}

public struct AtomicWriteCoordinator: Sendable {
    public init() {}

    public func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }
}
