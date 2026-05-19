import Foundation
import LLMCore
import LLMProtocols
import LLMSettings
import Observation

@MainActor
@Observable
final class DemoViewModel {
    private(set) var models: [ModelDescriptor]
    private(set) var availability: [ModelID: BackendAvailability]
    private(set) var installStates: [ModelID: InstallState]
    private(set) var sessions: [SessionOverview]
    private(set) var catalogStatus: ModelCatalogStatus
    private(set) var isRefreshing: Bool
    private(set) var lastErrorMessage: String?
    var settings: LLMRuntimeSettings {
        didSet {
            let normalized = Self.normalizer.normalized(
                settings,
                selectedModelContextWindowTokens: selectedModel?.contextWindowTokens
            )
            if normalized != settings {
                settings = normalized
                return
            }
            LLMRuntimeSettingsPersistence.save(settings, to: defaults, key: Self.settingsKey)
        }
    }

    @ObservationIgnored
    private let configuration: DemoRuntimeConfiguration
    @ObservationIgnored
    private let defaults: UserDefaults
    @ObservationIgnored
    private static let normalizer = LLMSettingsNormalizer()
    @ObservationIgnored
    private var preflight: DemoModelPreflight {
        DemoModelPreflight(
            catalog: configuration.catalog,
            catalogStatusProvider: configuration.catalogStatusProvider,
            backends: configuration.backends
        )
    }

    init(configuration: DemoRuntimeConfiguration, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.configuration = configuration
        self.models = []
        self.availability = [:]
        self.installStates = [:]
        self.sessions = []
        self.catalogStatus = .local
        self.isRefreshing = false
        self.lastErrorMessage = nil
        self.settings = DemoRuntimeSettingsMigration.load(from: defaults)
    }

    var selectedModelID: ModelID? {
        get { settings.preferredModelID }
        set { settings.preferredModelID = newValue }
    }

    var executionMode: ExecutionMode {
        get { settings.executionMode }
        set { settings.executionMode = newValue }
    }

    var qualityTier: QualityTier {
        get { settings.qualityTier }
        set { settings.qualityTier = newValue }
    }

    var privacyMode: PrivacyMode {
        get { settings.privacyMode }
        set { settings.privacyMode = newValue }
    }

    var maxOutputTokens: Int {
        get { settings.maxOutputTokens }
        set { settings.maxOutputTokens = newValue }
    }

    var selectedModel: ModelDescriptor? {
        guard let selectedModelID else {
            return nil
        }
        return models.first { $0.id == selectedModelID }
    }

    var downloadableModels: [ModelDescriptor] {
        models.filter { $0.tags.contains("downloadable") }
    }

    var chatSelectableModels: [ModelDescriptor] {
        models.filter(isReadyForChat)
    }

    var canChatWithSelectedModel: Bool {
        guard let selectedModel else {
            return false
        }
        return isReadyForChat(selectedModel)
    }

    func refresh() async {
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

    func refreshSessions() async throws {
        sessions = try await configuration.container.sessions.listSessions()
    }

    func model(for id: ModelID?) -> ModelDescriptor? {
        guard let id else {
            return nil
        }
        return models.first { $0.id == id }
    }

    func requirements(
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
            budget: Self.normalizer.executionBudget(
                for: settings,
                selectedModelContextWindowTokens: descriptor?.contextWindowTokens
            )
        )
    }

    func executionBudget(selectedModelContextWindowTokens: Int?) -> ExecutionBudget {
        Self.normalizer.executionBudget(
            for: settings,
            selectedModelContextWindowTokens: selectedModelContextWindowTokens
        )
    }

    @discardableResult
    func createManualSession() async throws -> SessionSnapshot {
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
    func createAutomatedSession(
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

    func loadSession(id: SessionID) async throws -> SessionSnapshot? {
        try await configuration.container.sessions.loadSession(id: id)
    }

    func deleteSession(id: SessionID) async throws {
        try await configuration.container.sessions.deleteSession(id: id)
        try await refreshSessions()
    }

    func deleteAllSessions() async throws {
        let sessionIDs = sessions.map(\.id)
        for sessionID in sessionIDs {
            try await configuration.container.sessions.deleteSession(id: sessionID)
        }
        try await refreshSessions()
    }

    func setLastErrorMessage(_ message: String?) {
        lastErrorMessage = message
    }

    @discardableResult
    func validateSelectedModelForChat() async throws -> ModelDescriptor {
        guard let selectedModel else {
            throw LLMError.modelSelectionFailed("Manual chat: no ready model is selected. Install or select a ready model from Models.")
        }
        return try await preflight.validate(
            requirements(for: selectedModel, preferredLatency: .interactive),
            context: "Manual chat"
        )
    }

    @discardableResult
    func validateExecutionRequirements(
        _ requirements: ExecutionRequirements,
        context: String
    ) async throws -> ModelDescriptor {
        try await preflight.validate(requirements, context: context)
    }

    func validateAutomatedConversation(
        definition: AutomatedConversationDefinition,
        executionRequirements: ExecutionRequirements
    ) async throws {
        try await preflight.validate(
            definition: definition,
            executionRequirements: executionRequirements,
            context: "Automated conversation"
        )
    }

    func validateAutomatedSession(_ snapshot: SessionSnapshot) async throws {
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

    func backendDescriptor(for overview: SessionOverview) -> ModelDescriptor? {
        model(for: overview.executionRequirements?.preferredModel)
    }

    func statusText(for descriptor: ModelDescriptor) -> String {
        if descriptor.tags.contains("system-managed") {
            return availabilityText(for: descriptor)
        }

        if let installState = installStates[descriptor.id] {
            return installText(for: installState)
        }

        return availabilityText(for: descriptor)
    }

    func isReadyForChat(_ descriptor: ModelDescriptor) -> Bool {
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
        let selectableModels = chatSelectableModels
        guard let selectedModelID else {
            selectedModelID = selectableModels.first?.id
            return
        }

        if !selectableModels.contains(where: { $0.id == selectedModelID }) {
            self.selectedModelID = selectableModels.first?.id
        }
    }

    private func installText(for state: InstallState) -> String {
        switch state {
        case .notInstalled:
            return "Not installed"
        case .downloading(let progress):
            return "Downloading \(Int((progress * 100).rounded()))%"
        case .paused(let progress):
            return "Paused \(Int((progress * 100).rounded()))%"
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

    private static let settingsKey = DemoRuntimeSettingsMigration.settingsKey
}
