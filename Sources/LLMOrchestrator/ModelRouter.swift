import LLMCore
import LLMProtocols

public struct ModelRouter: Sendable {
    private let catalog: any ModelCatalogProviding
    private let planner: ExecutionPlanner

    public init(catalog: any ModelCatalogProviding, planner: ExecutionPlanner = ExecutionPlanner()) {
        self.catalog = catalog
        self.planner = planner
    }

    public func route(requirements: ExecutionRequirements) async throws -> ModelDescriptor {
        let models = try await catalog.availableModels()
        let plan = planner.plan(models: models, requirements: requirements)
        if let preferred = requirements.preferredModel,
           let match = plan.candidates.first(where: { $0.id == preferred }) {
            return match
        }
        guard let selected = plan.candidates.first else {
            throw LLMError.unsupportedCapabilities(requirements.requiredCapabilities)
        }
        return selected
    }
}
