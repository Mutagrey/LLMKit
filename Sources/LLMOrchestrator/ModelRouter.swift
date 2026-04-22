import LLMCore
import LLMProtocols

public struct ModelRouter: Sendable {
    private let catalog: any ModelCatalogProviding
    private let planner: ExecutionPlanner

    public init(catalog: any ModelCatalogProviding, planner: ExecutionPlanner = ExecutionPlanner()) {
        self.catalog = catalog
        self.planner = planner
    }

    public func plan(requirements: ExecutionRequirements) async throws -> ExecutionPlan {
        let models = try await catalog.availableModels()
        let plan = planner.plan(models: models, requirements: requirements)
        guard !plan.candidates.isEmpty else {
            throw LLMError.unsupportedCapabilities(requirements.requiredCapabilities)
        }
        guard let preferred = requirements.preferredModel,
              let preferredIndex = plan.candidates.firstIndex(where: { $0.id == preferred }) else {
            return plan
        }
        var candidates = plan.candidates
        let preferredModel = candidates.remove(at: preferredIndex)
        candidates.insert(preferredModel, at: 0)
        return ExecutionPlan(candidates: candidates, requirements: requirements)
    }

    public func route(requirements: ExecutionRequirements) async throws -> ModelDescriptor {
        try await plan(requirements: requirements).candidates[0]
    }
}
