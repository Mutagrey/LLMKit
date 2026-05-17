import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LLMCore
import LLMProtocols

public actor HuggingFaceFeaturedModelCatalog: ModelCatalogProviding, ModelCatalogStatusProviding {
    private let fallbackCatalog: any ModelCatalogProviding
    private let fetchData: @Sendable (URL) async throws -> Data
    private let repositories: [FeaturedRepository]
    private var currentStatus: ModelCatalogStatus

    public init(
        fallbackCatalog: any ModelCatalogProviding,
        repositories: [String] = HuggingFaceFeaturedModelCatalog.defaultRepositoryIDs,
        fetchData: @escaping @Sendable (URL) async throws -> Data = HuggingFaceFeaturedModelCatalog.defaultFetchData
    ) {
        self.fallbackCatalog = fallbackCatalog
        self.fetchData = fetchData
        self.repositories = repositories.compactMap(FeaturedRepository.init(repositoryID:))
        self.currentStatus = .local
    }

    public func availableModels() async throws -> [ModelDescriptor] {
        let fallbackModels = try await fallbackCatalog.availableModels()
        let remoteResult = await loadRemoteModels()

        switch remoteResult {
        case .success(let models):
            guard !models.isEmpty else {
                currentStatus = ModelCatalogStatus(
                    source: .fallback,
                    message: "huggingface.co returned no featured models."
                )
                return fallbackModels
            }

            currentStatus = ModelCatalogStatus(
                source: .remoteVerified,
                message: "huggingface.co · \(models.count) live models"
            )
            return merge(local: fallbackModels, remote: models)
        case .failure(let message):
            currentStatus = ModelCatalogStatus(source: .fallback, message: message)
            return fallbackModels
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

    public static func defaultFetchData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw ManifestLoaderError.httpStatus(httpResponse.statusCode)
        }
        return data
    }

    public static let defaultRepositoryIDs = [
        "mlx-community/gemma-4-e2b-it-4bit",
        "mlx-community/Qwen3.5-2B-OptiQ-4bit",
        "mlx-community/Qwen3.5-4B-OptiQ-4bit",
        "mlx-community/Qwen3.6-27B-OptiQ-4bit",
        "mlx-community/gemma-3-text-4b-it-4bit",
        "mlx-community/gemma-3-text-12b-it-4bit"
    ]

    private func loadRemoteModels() async -> RemoteModelsLoadResult {
        await withTaskGroup(of: RemoteFetchResult.self) { group in
            for repository in repositories {
                group.addTask {
                    do {
                        return .success(try await self.fetchDescriptor(for: repository))
                    } catch {
                        return .failure(String(describing: error))
                    }
                }
            }

            var models: [ModelDescriptor] = []
            var failures: [String] = []

            for await result in group {
                switch result {
                case .success(let descriptor):
                    models.append(descriptor)
                case .failure(let message):
                    failures.append(message)
                }
            }

            if models.isEmpty {
                return .failure(failures.first ?? "huggingface.co fetch failed.")
            }

            return .success(models.sorted { $0.displayName < $1.displayName })
        }
    }

    private func fetchDescriptor(for repository: FeaturedRepository) async throws -> ModelDescriptor {
        let infoURL = try repository.infoURL()
        let data = try await fetchData(infoURL)
        let info = try JSONDecoder().decode(HuggingFaceModelInfo.self, from: data)
        let revision = info.sha ?? "main"
        let artifacts = info.siblings
            .filter { Self.isSupportedArtifactPath($0.relativePath) }
            .map { sibling in
                ModelArtifact(
                    id: sibling.relativePath,
                    url: repository.resolveURL(revision: revision, relativePath: sibling.relativePath),
                    relativePath: sibling.relativePath,
                    byteCount: sibling.size
                )
            }

        guard artifacts.contains(where: { $0.relativePath.hasSuffix(".safetensors") }) else {
            throw LLMError.downloadFailed("No weight files found for \(repository.repositoryID).")
        }
        guard artifacts.contains(where: { $0.relativePath == "config.json" }) else {
            throw LLMError.downloadFailed("config.json is missing for \(repository.repositoryID).")
        }

        let capabilities: Set<ModelCapability> = {
            var capabilities: Set<ModelCapability> = [.chat, .completion, .streaming, .offline]
            if let contextWindowTokens = repository.contextWindowTokens, contextWindowTokens > 32_768 {
                capabilities.insert(.longContext)
            }
            return capabilities
        }()

        return ModelDescriptor(
            id: repository.modelID,
            displayName: repository.displayName,
            family: repository.family,
            backend: .mlx,
            capabilities: capabilities,
            minimumRAMGB: repository.minimumRAMGB,
            minimumFreeDiskGB: repository.minimumFreeDiskGB,
            contextWindowTokens: repository.contextWindowTokens,
            supportsStreaming: true,
            source: ModelSource(
                provider: .huggingFace,
                repository: repository.repositoryID,
                revision: revision,
                homepageURL: repository.homepageURL,
                artifacts: artifacts
            ),
            license: repository.license,
            quantization: Quantization(format: "MLX 4-bit", bits: 4),
            estimatedDownloadSizeBytes: estimatedSize(for: artifacts),
            tags: repository.tags
        )
    }

    private func merge(local: [ModelDescriptor], remote: [ModelDescriptor]) -> [ModelDescriptor] {
        local
            .reduce(into: Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })) { partialResult, descriptor in
                partialResult[descriptor.id] = partialResult[descriptor.id] ?? descriptor
            }
            .values
            .sorted { $0.displayName < $1.displayName }
    }

    private func estimatedSize(for artifacts: [ModelArtifact]) -> Int64? {
        let knownSizes = artifacts.compactMap(\.byteCount)
        guard knownSizes.count == artifacts.count, !knownSizes.isEmpty else {
            return nil
        }
        return knownSizes.reduce(0, +)
    }

    private static func isSupportedArtifactPath(_ path: String) -> Bool {
        let lowercased = path.lowercased()
        if lowercased.hasSuffix(".safetensors") {
            return true
        }

        switch lowercased {
        case "config.json",
             "generation_config.json",
             "tokenizer.json",
             "tokenizer_config.json",
             "tokenizer.model",
             "special_tokens_map.json",
             "added_tokens.json",
             "merges.txt",
             "vocab.json",
             "preprocessor_config.json",
             "processor_config.json",
             "chat_template.jinja":
            return true
        default:
            return false
        }
    }
}

private enum RemoteFetchResult: Sendable {
    case success(ModelDescriptor)
    case failure(String)
}

private enum RemoteModelsLoadResult: Sendable {
    case success([ModelDescriptor])
    case failure(String)
}

private struct FeaturedRepository: Sendable {
    let repositoryID: String
    let modelID: ModelID
    let displayName: String
    let family: ModelFamily
    let minimumRAMGB: Int?
    let minimumFreeDiskGB: Int?
    let contextWindowTokens: Int?
    let tags: [String]
    let license: ModelLicense?
    let homepageURL: URL?

    init?(repositoryID: String) {
        self.repositoryID = repositoryID
        self.homepageURL = URL(string: "https://huggingface.co/\(repositoryID)")

        switch repositoryID {
        case "mlx-community/Qwen3.5-2B-OptiQ-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3.5 2B OptiQ 4-bit"
            family = .qwen
            minimumRAMGB = 8
            minimumFreeDiskGB = 3
            contextWindowTokens = 32768
            tags = ["downloadable", "mlx", "remote", "fast", "lightweight", "qwen", "starter"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/Qwen3.5-4B-OptiQ-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3.5 4B OptiQ 4-bit"
            family = .qwen
            minimumRAMGB = 12
            minimumFreeDiskGB = 5
            contextWindowTokens = 32768
            tags = ["downloadable", "mlx", "remote", "balanced", "qwen", "quality"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/Qwen3.6-27B-OptiQ-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3.6 27B OptiQ 4-bit"
            family = .qwen
            minimumRAMGB = 32
            minimumFreeDiskGB = 20
            contextWindowTokens = 131072
            tags = ["downloadable", "mlx", "remote", "pro", "qwen", "quality"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/gemma-4-e2b-it-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Gemma 4 E2B Instruct 4-bit"
            family = .gemma
            minimumRAMGB = 8
            minimumFreeDiskGB = 5
            contextWindowTokens = 131072
            tags = ["downloadable", "mlx", "remote", "gemma", "gemma4", "iphone-pro", "agentic"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/gemma-3-text-4b-it-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Gemma 3 Text 4B Instruct 4-bit"
            family = .gemma
            minimumRAMGB = 12
            minimumFreeDiskGB = 4
            contextWindowTokens = 32768
            tags = ["downloadable", "mlx", "remote", "balanced", "gemma", "recommended"]
            license = Self.gemmaLicense
        case "mlx-community/gemma-3-text-12b-it-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Gemma 3 Text 12B Instruct 4-bit"
            family = .gemma
            minimumRAMGB = 24
            minimumFreeDiskGB = 10
            contextWindowTokens = 32768
            tags = ["downloadable", "mlx", "remote", "gemma", "quality", "pro"]
            license = Self.gemmaLicense
        default:
            return nil
        }
    }

    func infoURL() throws -> URL {
        guard let encodedRepository = repositoryID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://huggingface.co/api/models/\(encodedRepository)?full=true") else {
            throw LLMError.downloadFailed("Invalid repository URL for \(repositoryID).")
        }
        return url
    }

    func resolveURL(revision: String, relativePath: String) -> URL {
        URL(string: "https://huggingface.co/\(repositoryID)/resolve/\(revision)/\(relativePath)")!
    }

    private static func apacheTwoLicense(for repositoryID: String) -> ModelLicense {
        ModelLicense(
            name: "Apache License 2.0",
            spdxIdentifier: "Apache-2.0",
            url: URL(string: "https://huggingface.co/\(repositoryID)/blob/main/LICENSE")
        )
    }

    private static let gemmaLicense = ModelLicense(
        name: "Gemma License",
        url: URL(string: "https://ai.google.dev/gemma/terms")
    )
}

private struct HuggingFaceModelInfo: Decodable {
    let sha: String?
    let siblings: [HuggingFaceModelSibling]
}

private struct HuggingFaceModelSibling: Decodable {
    let relativePath: String
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case relativePath = "rfilename"
        case size
    }
}
