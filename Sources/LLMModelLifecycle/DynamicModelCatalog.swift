import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LLMCore
import LLMProtocols

public struct RemoteModelCatalogSource: Hashable, Sendable {
    public let url: URL
    public let signature: ModelManifestSignature

    public init(url: URL, signature: ModelManifestSignature) {
        self.url = url
        self.signature = signature
    }
}

public actor DynamicModelCatalog: ModelCatalogProviding, ModelManifestProviding, ModelCatalogStatusProviding {
    private let remoteSource: RemoteModelCatalogSource
    private let fallbackCatalog: any ModelCatalogProviding
    private let loader: ManifestLoader
    private let fetchManifestData: @Sendable (URL) async throws -> Data
    private let validator: ModelManifestValidator
    private var cachedRemoteManifest: ModelManifest?
    private var currentStatus: ModelCatalogStatus

    public init(
        remoteSource: RemoteModelCatalogSource,
        fallbackCatalog: any ModelCatalogProviding,
        loader: ManifestLoader = ManifestLoader(),
        fetchManifestData: @escaping @Sendable (URL) async throws -> Data = DynamicModelCatalog.defaultFetchManifestData,
        validator: ModelManifestValidator = ModelManifestValidator()
    ) {
        self.remoteSource = remoteSource
        self.fallbackCatalog = fallbackCatalog
        self.loader = loader
        self.fetchManifestData = fetchManifestData
        self.validator = validator
        self.currentStatus = .local
    }

    public func availableModels() async throws -> [ModelDescriptor] {
        do {
            let manifest = try await remoteManifest()
            currentStatus = ModelCatalogStatus(
                source: .remoteVerified,
                message: remoteSource.url.host ?? remoteSource.url.absoluteString
            )
            return manifest.models.sorted { $0.displayName < $1.displayName }
        } catch {
            currentStatus = ModelCatalogStatus(
                source: .fallback,
                message: String(describing: error)
            )
            return try await fallbackCatalog.availableModels()
        }
    }

    public func manifestModels() async throws -> [ModelDescriptor] {
        try await availableModels()
    }

    public func descriptor(for id: ModelID) async throws -> ModelDescriptor? {
        try await availableModels().first { $0.id == id }
    }

    public func catalogStatus() async -> ModelCatalogStatus {
        currentStatus
    }

    public func refresh() async throws -> ModelManifest {
        let manifest = try await loadRemoteManifest()
        cachedRemoteManifest = manifest
        return manifest
    }

    private func remoteManifest() async throws -> ModelManifest {
        if let cachedRemoteManifest {
            return cachedRemoteManifest
        }
        return try await refresh()
    }

    private func loadRemoteManifest() async throws -> ModelManifest {
        guard remoteSource.signature.algorithm.lowercased() == "ed25519",
              remoteSource.signature.publicKeyValue != nil else {
            throw LLMError.verificationFailed("Remote model catalogs require an Ed25519 manifest signature.")
        }
        let data = try await fetchManifestData(remoteSource.url)
        let manifest = try loader.load(data: data, expectedSignature: remoteSource.signature)
        try validator.validateInternetLoadedManifest(manifest)
        return manifest
    }

    public static func defaultFetchManifestData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw ManifestLoaderError.httpStatus(httpResponse.statusCode)
            }
        }
        return data
    }
}

public struct ModelManifestValidator: Sendable {
    public init() {}

    public func validateInternetLoadedManifest(_ manifest: ModelManifest) throws {
        for descriptor in manifest.models {
            guard let source = descriptor.source else {
                continue
            }
            for artifact in source.artifacts where requiresChecksum(source.provider) {
                guard artifact.checksum != nil else {
                    throw LLMError.verificationFailed("Remote manifest artifact \(artifact.relativePath) is missing a checksum.")
                }
            }
        }
    }

    private func requiresChecksum(_ provider: ModelSourceProvider) -> Bool {
        switch provider {
        case .huggingFace, .remoteURL:
            return true
        case .bundled, .custom:
            return false
        }
    }
}
