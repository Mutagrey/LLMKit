import LLMCore
import LLMProtocols
import Observation

@MainActor
@Observable
public final class LLMKitExampleViewModel {
    public private(set) var models: [ModelDescriptor]
    public private(set) var availability: [ModelID: BackendAvailability]
    public private(set) var installStates: [ModelID: InstallState]
    public private(set) var isRefreshing: Bool
    public private(set) var lastErrorMessage: String?
    public var selectedModelID: ModelID?
    public var executionMode: ExecutionMode
    public var qualityTier: QualityTier
    public var privacyMode: PrivacyMode
    public var maxOutputTokens: Int

    @ObservationIgnored
    private let configuration: LLMKitExampleConfiguration

    public init(configuration: LLMKitExampleConfiguration) {
        self.configuration = configuration
        self.models = []
        self.availability = [:]
        self.installStates = [:]
        self.isRefreshing = false
        self.lastErrorMessage = nil
        self.selectedModelID = nil
        self.executionMode = .preferOffline
        self.qualityTier = .balanced
        self.privacyMode = .localOnly
        self.maxOutputTokens = 512
    }

    public var selectedModel: ModelDescriptor? {
        guard let selectedModelID else {
            return models.first
        }
        return models.first { $0.id == selectedModelID } ?? models.first
    }

    public var chatRequirements: ExecutionRequirements {
        ExecutionRequirements(
            requiredCapabilities: [.chat],
            executionMode: executionMode,
            preferredLatency: .interactive,
            qualityTier: qualityTier,
            preferredModel: selectedModel?.id,
            privacyMode: privacyMode,
            budget: ExecutionBudget(maxOutputTokens: maxOutputTokens)
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
            if selectedModelID == nil {
                selectedModelID = models.first?.id
            }
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
}
