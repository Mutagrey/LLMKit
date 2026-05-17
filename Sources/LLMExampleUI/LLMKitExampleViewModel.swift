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
    public private(set) var sessions: [SessionOverview]
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
    @ObservationIgnored
    private var preflight: ExampleModelPreflight {
        ExampleModelPreflight(
            catalog: configuration.catalog,
            catalogStatusProvider: configuration.catalogStatusProvider,
            backends: configuration.backends
        )
    }

    public init(configuration: LLMKitExampleConfiguration, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.configuration = configuration
        self.models = []
        self.availability = [:]
        self.installStates = [:]
        self.sessions = []
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
            return nil
        }
        return models.first { $0.id == selectedModelID }
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

    public var chatSelectableModels: [ModelDescriptor] {
        models.filter(isReadyForChat)
    }

    public var canChatWithSelectedModel: Bool {
        guard let selectedModel else {
            return false
        }
        return isReadyForChat(selectedModel)
    }

    public var chatRequirements: ExecutionRequirements {
        requirements(for: selectedModel, preferredLatency: .interactive)
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
            try await refreshInstallStates()
            await refreshAvailability()
            normalizeSelectedModel()
            try await refreshSessions()
        } catch {
            lastErrorMessage = String(describing: error)
        }
        isRefreshing = false
    }

    public func refreshSessions() async throws {
        sessions = try await configuration.container.sessions.listSessions()
    }

    public func model(for id: ModelID?) -> ModelDescriptor? {
        guard let id else {
            return nil
        }
        return models.first { $0.id == id }
    }

    public func requirements(
        for descriptor: ModelDescriptor?,
        preferredLatency: PreferredLatency,
        selectionPolicy: ModelSelectionPolicy? = nil
    ) -> ExecutionRequirements {
        let resolvedPolicy = selectionPolicy ?? descriptor.map { .require($0.id) } ?? .automatic
        return ExecutionRequirements(
            requiredCapabilities: [.chat],
            selectionPolicy: resolvedPolicy,
            executionMode: executionMode,
            preferredLatency: preferredLatency,
            qualityTier: qualityTier,
            privacyMode: privacyMode,
            budget: ExecutionBudget(
                maxInputTokens: descriptor?.contextWindowTokens,
                maxOutputTokens: maxOutputTokens
            )
        )
    }

    @discardableResult
    public func createManualSession() async throws -> SessionSnapshot {
        _ = try await validateSelectedModelForChat()
        let snapshot = try await configuration.container.sessions.createSession(
            title: nil,
            kind: .manualChat,
            executionRequirements: requirements(for: selectedModel, preferredLatency: .interactive),
            automationDefinition: nil,
            automationState: nil
        )
        try await refreshSessions()
        return snapshot
    }

    @discardableResult
    public func createAutomatedSession(
        title: String?,
        definition: AutomatedConversationDefinition,
        executionRequirements: ExecutionRequirements
    ) async throws -> SessionSnapshot {
        try await validateAutomatedConversation(
            definition: definition,
            executionRequirements: executionRequirements
        )
        let snapshot = try await configuration.container.sessions.createSession(
            title: title,
            kind: .automatedConversation,
            executionRequirements: executionRequirements,
            automationDefinition: definition,
            automationState: AutomatedConversationRunState()
        )
        try await refreshSessions()
        return snapshot
    }

    public func loadSession(id: SessionID) async throws -> SessionSnapshot? {
        try await configuration.container.sessions.loadSession(id: id)
    }

    public func saveSession(_ snapshot: SessionSnapshot) async throws {
        try await configuration.container.sessions.saveSession(snapshot)
        try await refreshSessions()
    }

    public func deleteSession(id: SessionID) async throws {
        try await configuration.container.sessions.deleteSession(id: id)
        try await refreshSessions()
    }

    public func setLastErrorMessage(_ message: String?) {
        lastErrorMessage = message
    }

    @discardableResult
    public func validateSelectedModelForChat() async throws -> ModelDescriptor {
        guard let selectedModel else {
            throw LLMError.modelSelectionFailed("Manual chat: no ready model is selected. Install or select a ready model from Models.")
        }
        return try await preflight.validate(
            requirements(for: selectedModel, preferredLatency: .interactive),
            context: "Manual chat"
        )
    }

    @discardableResult
    public func validateExecutionRequirements(
        _ requirements: ExecutionRequirements,
        context: String
    ) async throws -> ModelDescriptor {
        try await preflight.validate(requirements, context: context)
    }

    public func validateAutomatedConversation(
        definition: AutomatedConversationDefinition,
        executionRequirements: ExecutionRequirements
    ) async throws {
        try await preflight.validate(
            definition: definition,
            executionRequirements: executionRequirements,
            context: "Automated conversation"
        )
    }

    public func validateAutomatedSession(_ snapshot: SessionSnapshot) async throws {
        guard let definition = snapshot.automationDefinition else {
            throw LLMError.executionFailed("Automated conversation definition is missing.")
        }
        let requirements = snapshot.executionRequirements
            ?? ExecutionRequirements(requiredCapabilities: [.chat], preferredLatency: .background)
        try await validateAutomatedConversation(
            definition: definition,
            executionRequirements: requirements
        )
    }

    public func backendDescriptor(for overview: SessionOverview) -> ModelDescriptor? {
        model(for: overview.executionRequirements?.preferredModel)
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

    public func isReadyForChat(_ descriptor: ModelDescriptor) -> Bool {
        isAvailable(descriptor)
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
        let selectableModels = chatSelectableModels
        guard let selectedModelID else {
            selectedModelID = selectableModels.first?.id
            return
        }

        if !selectableModels.contains(where: { $0.id == selectedModelID }) {
            self.selectedModelID = selectableModels.first?.id
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
