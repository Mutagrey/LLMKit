import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LLMCore
import LLMProtocols

public struct ManifestLoader: Sendable {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let integrityVerifier: ModelIntegrityVerifier

    public init(
        decoder: JSONDecoder? = nil,
        encoder: JSONEncoder? = nil,
        integrityVerifier: ModelIntegrityVerifier = ModelIntegrityVerifier()
    ) {
        self.decoder = decoder ?? ManifestLoader.makeDecoder()
        self.encoder = encoder ?? ManifestLoader.makeEncoder()
        self.integrityVerifier = integrityVerifier
    }

    public func load(data: Data, expectedSignature: ModelManifestSignature? = nil) throws -> ModelManifest {
        if let expectedSignature {
            _ = try integrityVerifier.verifyManifestData(data, signature: expectedSignature)
        }
        return try decoder.decode(ModelManifest.self, from: data)
    }

    public func load(contentsOf fileURL: URL, expectedSignature: ModelManifestSignature? = nil) throws -> ModelManifest {
        try load(data: Data(contentsOf: fileURL), expectedSignature: expectedSignature)
    }

    public func load(
        named name: String,
        from store: any ManifestStore,
        expectedSignature: ModelManifestSignature? = nil
    ) async throws -> ModelManifest? {
        guard let data = try await store.loadManifest(named: name) else {
            return nil
        }
        return try load(data: data, expectedSignature: expectedSignature)
    }

    public func load(
        remoteManifestAt url: URL,
        expectedSignature: ModelManifestSignature? = nil,
        session: URLSession = .shared
    ) async throws -> ModelManifest {
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw ManifestLoaderError.httpStatus(httpResponse.statusCode)
            }
        }
        return try load(data: data, expectedSignature: expectedSignature)
    }

    public func save(_ manifest: ModelManifest, named name: String, to store: any ManifestStore) async throws {
        try await store.saveManifest(encoded(manifest), named: name)
    }

    public func encoded(_ manifest: ModelManifest) throws -> Data {
        try encoder.encode(manifest)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

public enum ManifestLoaderError: Error, Hashable, Sendable {
    case httpStatus(Int)
}
