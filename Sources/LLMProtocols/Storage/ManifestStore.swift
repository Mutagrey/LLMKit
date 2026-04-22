import Foundation
import LLMCore

public protocol ManifestStore: Sendable {
    func loadManifest(named name: String) async throws -> Data?
    func saveManifest(_ data: Data, named name: String) async throws
}

public protocol BinaryAssetStore: Sendable {
    func containsAsset(named name: String) async throws -> Bool
    func removeAsset(named name: String) async throws
}

public protocol CacheStore: Sendable {
    func removeAll() async throws
}
