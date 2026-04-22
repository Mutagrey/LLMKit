import Foundation
import LLMCore
import LLMProtocols

public actor InstalledModelRecordStore {
    private let manifestStore: any ManifestStore
    private let manifestName: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        manifestStore: any ManifestStore,
        manifestName: String = "installed-models.json",
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.manifestStore = manifestStore
        self.manifestName = manifestName
        self.decoder = decoder
        self.encoder = encoder
    }

    public func load() async throws -> [InstalledModelRecord] {
        guard let data = try await manifestStore.loadManifest(named: manifestName) else {
            return []
        }
        return try decoder.decode([InstalledModelRecord].self, from: data)
    }

    public func save(_ records: [InstalledModelRecord]) async throws {
        let data = try encoder.encode(records.sorted { $0.descriptor.displayName < $1.descriptor.displayName })
        try await manifestStore.saveManifest(data, named: manifestName)
    }
}
