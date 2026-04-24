import Foundation
import LLMCore
import LLMProtocols
import Observation

@MainActor
@Observable
public final class LLMKitExampleViewModel {
    public private(set) var models: [ModelDescriptor]
    public private(set) var availability: [ModelID: BackendAvailability]
    public private(set) var installStates: [ModelID: InstallState]
    public private(set) var catalogStatus: ModelCatalogStatus
    public private(set) var isRefreshing: Bool
    public private(set) var lastErrorMessage: String?
    public var selectedModelID: ModelID? {
        didSet {
            persistSelectedModelID()
        }
    }
    public var executionMode: ExecutionMode {
        didSet {
            defaults.set(executionMode.rawValue, forKey: Self.executionModeKey)
        }
    }
    public var qualityTier: QualityTier {
        didSet {
            defaults.set(qualityTier.rawValue, forKey: Self.qualityTierKey)
        }
    }
    public var privacyMode: PrivacyMode {
        didSet {
            defaults.set(privacyMode.rawValue, forKey: Self.privacyModeKey)
        }
    }
    public var maxOutputTokens: Int {
        didSet {
            let clampedValue = max(64, min(maxOutputTokens, 4096))
            if clampedValue != maxOutputTokens {
                maxOutputTokens = clampedValue
                return
            }
            defaults.set(maxOutputTokens, forKey: Self.maxOutputTokensKey)
        }
    }

    @ObservationIgnored
    private let configuration: LLMKitExampleConfiguration
    @ObservationIgnored
    private let defaults: UserDefaults

    public init(configuration: LLMKitExampleConfiguration, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.configuration = configuration
        self.models = []
        self.availability = [:]
        self.installStates = [:]
        self.catalogStatus = .local
        self.isRefreshing = false
        self.lastErrorMessage = nil
        self.selectedModelID = defaults.string(forKey: Self.selectedModelIDKey).map(ModelID.init(rawValue:))
        self.executionMode = Self.persistedExecutionMode(from: defaults)
        self.qualityTier = Self.persistedQualityTier(from: defaults)
        self.privacyMode = Self.persistedPrivacyMode(from: defaults)
        self.maxOutputTokens = Self.persistedMaxOutputTokens(from: defaults)
    }

    public var selectedModel: ModelDescriptor? {
        guard let selectedModelID else {
            return models.first
        }
        return models.first { $0.id == selectedModelID } ?? models.first
    }

    public var selectedModelAvailability: BackendAvailability? {
        guard let selectedModel else {
            return nil
        }
        return availability[selectedModel.id]
    }

    public var downloadableModels: [ModelDescriptor] {
        models.filter { $0.tags.contains("downloadable") }
    }

    public var canChatWithSelectedModel: Bool {
        selectedModelAvailability?.status == .available
    }

    public var chatRequirements: ExecutionRequirements {
        ExecutionRequirements(
            requiredCapabilities: [.chat],
            executionMode: executionMode,
            preferredLatency: .interactive,
            qualityTier: qualityTier,
            preferredModel: selectedModel?.id,
            privacyMode: privacyMode,
            budget: ExecutionBudget(maxOutputTokens: maxOutputTokens),
            allowsFallback: false
        )
    }

    public var chatIdentity: String {
        [
            selectedModel?.id.rawValue ?? "none",
            executionMode.rawValue,
            qualityTier.rawValue,
            privacyMode.rawValue,
            String(maxOutputTokens)
        ].joined(separator: ":")
    }

    public func refresh() async {
        isRefreshing = true
        lastErrorMessage = nil
        do {
            models = try await configuration.catalog.availableModels()
            if let catalogStatusProvider = configuration.catalogStatusProvider {
                catalogStatus = await catalogStatusProvider.catalogStatus()
            } else {
                catalogStatus = .local
            }
            normalizeSelectedModel()
            try await refreshInstallStates()
            await refreshAvailability()
        } catch {
            lastErrorMessage = String(describing: error)
        }
        isRefreshing = false
    }

    public func statusText(for descriptor: ModelDescriptor) -> String {
        if isSystemManaged(descriptor) {
            return availabilityText(for: descriptor)
        }

        if let installState = installStates[descriptor.id] {
            return installText(for: installState)
        }

        return availabilityText(for: descriptor)
    }

    public func isSystemManaged(_ descriptor: ModelDescriptor) -> Bool {
        descriptor.tags.contains("system-managed")
    }

    public func isAvailable(_ descriptor: ModelDescriptor) -> Bool {
        availability[descriptor.id]?.status == .available
    }

    private func refreshInstallStates() async throws {
        let records = try await configuration.container.lifecycle.installedModels()
        installStates = Dictionary(uniqueKeysWithValues: records.map { ($0.descriptor.id, $0.installState) })
    }

    private func refreshAvailability() async {
        var resolvedAvailability: [ModelID: BackendAvailability] = [:]
        for descriptor in models {
            guard let backend = configuration.backend(for: descriptor.backend) else {
                resolvedAvailability[descriptor.id] = .unsupported
                continue
            }
            resolvedAvailability[descriptor.id] = await backend.availability(for: descriptor)
        }
        availability = resolvedAvailability
    }

    private func availabilityText(for descriptor: ModelDescriptor) -> String {
        switch availability[descriptor.id]?.status {
        case .available:
            return "Available"
        case .unavailable(let reason):
            return reason
        case .requiresInstall:
            return "Install required"
        case .requiresNetwork:
            return "Network required"
        case .unsupported:
            return "Unsupported"
        case nil:
            return "Checking"
        }
    }

    private func normalizeSelectedModel() {
        guard let selectedModelID else {
            selectedModelID = models.first?.id
            return
        }

        if !models.contains(where: { $0.id == selectedModelID }) {
            self.selectedModelID = models.first?.id
        }
    }

    private func persistSelectedModelID() {
        if let selectedModelID {
            defaults.set(selectedModelID.rawValue, forKey: Self.selectedModelIDKey)
        } else {
            defaults.removeObject(forKey: Self.selectedModelIDKey)
        }
    }

    private func installText(for state: InstallState) -> String {
        switch state {
        case .notInstalled:
            return "Not installed"
        case .downloading(let progress):
            return "Downloading \(Int((progress * 100).rounded()))%"
        case .downloaded:
            return "Downloaded"
        case .verifying:
            return "Verifying"
        case .compiling:
            return "Compiling"
        case .ready:
            return "Ready"
        case .warming:
            return "Warming"
        case .active:
            return "Active"
        case .failed(let message):
            return "Failed: \(message)"
        case .evicted(let reason):
            return "Evicted: \(String(describing: reason))"
        }
    }

    private static let selectedModelIDKey = "llmkit.example.selectedModelID"
    private static let executionModeKey = "llmkit.example.executionMode"
    private static let qualityTierKey = "llmkit.example.qualityTier"
    private static let privacyModeKey = "llmkit.example.privacyMode"
    private static let maxOutputTokensKey = "llmkit.example.maxOutputTokens"

    private static func persistedExecutionMode(from defaults: UserDefaults) -> ExecutionMode {
        guard let rawValue = defaults.string(forKey: executionModeKey),
              let mode = ExecutionMode(rawValue: rawValue) else {
            return .preferOffline
        }
        return mode
    }

    private static func persistedQualityTier(from defaults: UserDefaults) -> QualityTier {
        guard let rawValue = defaults.string(forKey: qualityTierKey),
              let tier = QualityTier(rawValue: rawValue) else {
            return .balanced
        }
        return tier
    }

    private static func persistedPrivacyMode(from defaults: UserDefaults) -> PrivacyMode {
        guard let rawValue = defaults.string(forKey: privacyModeKey),
              let mode = PrivacyMode(rawValue: rawValue) else {
            return .localOnly
        }
        return mode
    }

    private static func persistedMaxOutputTokens(from defaults: UserDefaults) -> Int {
        let storedValue = defaults.object(forKey: maxOutputTokensKey) as? Int ?? 512
        return max(64, min(storedValue, 4096))
    }
}
