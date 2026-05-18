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
        "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
        "mlx-community/Qwen3.5-2B-OptiQ-4bit",
        "mlx-community/Qwen3.5-4B-OptiQ-4bit",
        "mlx-community/Qwen3-4B-Instruct-2507-4bit",
        "mlx-community/gemma-4-e2b-it-4bit",
        "mlx-community/Llama-3.2-1B-Instruct-4bit",
        "mlx-community/Llama-3.2-3B-Instruct-4bit",
        "mlx-community/Josiefied-Qwen3-1.7B-abliterated-v1-4bit",
        "mlx-community/Josiefied-Qwen3-8B-abliterated-v1-4bit",
        "mlx-community/Qwen2.5-7B-Instruct-Uncensored-4bit",
        "mlx-community/Qwen3-4B-Sky-High-Hermes-gabliterated-4bit",
        "mlx-community/Llama-3.2-3B-Instruct-uncensored-6bit",
        "mlx-community/Meta-Llama-3.1-8B-Instruct-abliterated-4bit"
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

            return .success(Self.sortedByPopularity(models))
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
            quantization: quantization(for: repository.repositoryID),
            estimatedDownloadSizeBytes: estimatedSize(for: artifacts) ?? repository.estimatedDownloadSizeBytes,
            tags: repository.tags + info.statTags
        )
    }

    private func quantization(for repositoryID: String) -> Quantization {
        if repositoryID.localizedCaseInsensitiveContains("6bit") ||
            repositoryID.localizedCaseInsensitiveContains("6-bit") {
            return Quantization(format: "MLX 6-bit", bits: 6)
        }
        return Quantization(format: "MLX 4-bit", bits: 4)
    }

    private func merge(local: [ModelDescriptor], remote: [ModelDescriptor]) -> [ModelDescriptor] {
        Self.sortedByPopularity(local
            .reduce(into: Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })) { partialResult, descriptor in
                partialResult[descriptor.id] = partialResult[descriptor.id] ?? descriptor
            }
            .values
            .map { $0 })
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

    private static func sortedByPopularity(_ models: [ModelDescriptor]) -> [ModelDescriptor] {
        models.sorted { lhs, rhs in
            let lhsDownloads = tagValue("hf-downloads:", in: lhs.tags) ?? 0
            let rhsDownloads = tagValue("hf-downloads:", in: rhs.tags) ?? 0
            if lhsDownloads != rhsDownloads {
                return lhsDownloads > rhsDownloads
            }

            let lhsLikes = tagValue("hf-likes:", in: lhs.tags) ?? 0
            let rhsLikes = tagValue("hf-likes:", in: rhs.tags) ?? 0
            if lhsLikes != rhsLikes {
                return lhsLikes > rhsLikes
            }

            return lhs.displayName < rhs.displayName
        }
    }

    private static func tagValue(_ prefix: String, in tags: [String]) -> Int? {
        tags
            .lazy
            .first { $0.hasPrefix(prefix) }
            .flatMap { Int($0.dropFirst(prefix.count)) }
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
    let estimatedDownloadSizeBytes: Int64?
    let tags: [String]
    let license: ModelLicense?
    let homepageURL: URL?

    init?(repositoryID: String) {
        self.repositoryID = repositoryID
        self.homepageURL = URL(string: "https://huggingface.co/\(repositoryID)")

        switch repositoryID {
        case "mlx-community/Qwen3.5-0.8B-OptiQ-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3.5 0.8B OptiQ 4-bit"
            family = .qwen
            minimumRAMGB = 4
            minimumFreeDiskGB = 1
            contextWindowTokens = 32768
            estimatedDownloadSizeBytes = 650_257_188
            tags = ["downloadable", "mlx", "remote", "qwen", "starter", "optiq", "latest"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/Qwen3.5-2B-OptiQ-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3.5 2B OptiQ 4-bit"
            family = .qwen
            minimumRAMGB = 6
            minimumFreeDiskGB = 2
            contextWindowTokens = 32768
            estimatedDownloadSizeBytes = 1_533_885_748
            tags = ["downloadable", "mlx", "remote", "balanced", "qwen", "iphone-recommended", "optiq", "latest"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/Qwen3.5-4B-OptiQ-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3.5 4B OptiQ 4-bit"
            family = .qwen
            minimumRAMGB = 8
            minimumFreeDiskGB = 4
            contextWindowTokens = 32768
            estimatedDownloadSizeBytes = 3_269_669_552
            tags = ["downloadable", "mlx", "remote", "quality", "qwen", "iphone-pro", "optiq", "latest"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/Qwen3-4B-Instruct-2507-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3 4B Instruct 2507 4-bit"
            family = .qwen
            minimumRAMGB = 8
            minimumFreeDiskGB = 4
            contextWindowTokens = 32768
            estimatedDownloadSizeBytes = 2_263_022_417
            tags = ["downloadable", "mlx", "remote", "quality", "qwen", "iphone-pro", "instruct"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/gemma-4-e2b-it-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Gemma 4 E2B Instruct 4-bit"
            family = .gemma
            minimumRAMGB = 8
            minimumFreeDiskGB = 5
            contextWindowTokens = 131072
            estimatedDownloadSizeBytes = 3_843_248_947
            tags = ["downloadable", "mlx", "remote", "gemma", "gemma4", "iphone-pro", "agentic"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/gemma-4-e2b-it-OptiQ-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Gemma 4 E2B Instruct OptiQ 4-bit"
            family = .gemma
            minimumRAMGB = 8
            minimumFreeDiskGB = 5
            contextWindowTokens = 131072
            estimatedDownloadSizeBytes = 4_296_816_768
            tags = ["downloadable", "mlx", "remote", "gemma", "gemma4", "iphone-pro", "agentic", "optiq"]
            license = Self.gemmaLicense
        case "mlx-community/Llama-3.2-1B-Instruct-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Llama 3.2 1B Instruct 4-bit"
            family = .llama
            minimumRAMGB = 4
            minimumFreeDiskGB = 1
            contextWindowTokens = 131072
            estimatedDownloadSizeBytes = 695_283_921
            tags = ["downloadable", "mlx", "remote", "llama", "starter", "iphone-entry"]
            license = Self.llamaLicense(for: repositoryID)
        case "mlx-community/Llama-3.2-3B-Instruct-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Llama 3.2 3B Instruct 4-bit"
            family = .llama
            minimumRAMGB = 8
            minimumFreeDiskGB = 3
            contextWindowTokens = 131072
            estimatedDownloadSizeBytes = 1_807_496_278
            tags = ["downloadable", "mlx", "remote", "llama", "balanced", "iphone-recommended"]
            license = Self.llamaLicense(for: repositoryID)
        case "mlx-community/Josiefied-Qwen3-1.7B-abliterated-v1-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3 1.7B Abliterated 4-bit"
            family = .qwen
            minimumRAMGB = 6
            minimumFreeDiskGB = 2
            contextWindowTokens = 32768
            estimatedDownloadSizeBytes = 968_079_703
            tags = ["downloadable", "mlx", "remote", "qwen", "experimental", "uncensored", "abliterated"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/Josiefied-Qwen3-8B-abliterated-v1-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3 8B Abliterated 4-bit"
            family = .qwen
            minimumRAMGB = 8
            minimumFreeDiskGB = 5
            contextWindowTokens = 32768
            estimatedDownloadSizeBytes = 4_607_835_164
            tags = ["downloadable", "mlx", "remote", "qwen", "quality", "iphone-pro", "uncensored", "abliterated"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/Qwen2.5-7B-Instruct-Uncensored-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen2.5 7B Instruct Uncensored 4-bit"
            family = .qwen
            minimumRAMGB = 8
            minimumFreeDiskGB = 5
            contextWindowTokens = 32768
            estimatedDownloadSizeBytes = 4_284_346_187
            tags = ["downloadable", "mlx", "remote", "qwen", "quality", "iphone-pro", "uncensored", "gpl-3.0"]
            license = ModelLicense(
                name: "GNU General Public License v3.0",
                spdxIdentifier: "GPL-3.0",
                url: URL(string: "https://huggingface.co/\(repositoryID)/blob/main/LICENSE")
            )
        case "mlx-community/Qwen3-4B-Sky-High-Hermes-gabliterated-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Qwen3 4B Sky High Hermes Gabliterated 4-bit"
            family = .qwen
            minimumRAMGB = 8
            minimumFreeDiskGB = 4
            contextWindowTokens = 32768
            estimatedDownloadSizeBytes = 2_262_637_937
            tags = ["downloadable", "mlx", "remote", "qwen", "experimental", "uncensored", "gabliterated", "hermes"]
            license = Self.apacheTwoLicense(for: repositoryID)
        case "mlx-community/Llama-3.2-3B-Instruct-uncensored-6bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Llama 3.2 3B Instruct Uncensored 6-bit"
            family = .llama
            minimumRAMGB = 8
            minimumFreeDiskGB = 3
            contextWindowTokens = 131072
            estimatedDownloadSizeBytes = 2_610_640_196
            tags = ["downloadable", "mlx", "remote", "llama", "balanced", "iphone-pro", "uncensored"]
            license = Self.llamaLicense(for: repositoryID)
        case "mlx-community/Meta-Llama-3.1-8B-Instruct-abliterated-4bit":
            modelID = ModelID(rawValue: repositoryID.replacingOccurrences(of: "/", with: "."))
            displayName = "Llama 3.1 8B Instruct Abliterated 4-bit"
            family = .llama
            minimumRAMGB = 8
            minimumFreeDiskGB = 5
            contextWindowTokens = 131072
            estimatedDownloadSizeBytes = 4_517_489_037
            tags = ["downloadable", "mlx", "remote", "llama", "quality", "iphone-pro", "uncensored", "abliterated"]
            license = Self.llamaLicense(for: repositoryID)
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

    private static func llamaLicense(for repositoryID: String) -> ModelLicense {
        ModelLicense(
            name: "Llama Community License",
            url: URL(string: "https://huggingface.co/\(repositoryID)/blob/main/LICENSE")
        )
    }
}

private struct HuggingFaceModelInfo: Decodable {
    let sha: String?
    let downloads: Int?
    let likes: Int?
    let siblings: [HuggingFaceModelSibling]

    var statTags: [String] {
        var tags: [String] = []
        if let downloads {
            tags.append("hf-downloads:\(downloads)")
        }
        if let likes {
            tags.append("hf-likes:\(likes)")
        }
        return tags
    }
}

private struct HuggingFaceModelSibling: Decodable {
    let relativePath: String
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case relativePath = "rfilename"
        case size
    }
}
