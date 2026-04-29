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
            if case .require(let modelID) = requirements.selectionPolicy {
                throw LLMError.modelSelectionFailed("Required model \(modelID.rawValue) does not satisfy the current request or is unavailable in the active catalog.")
            }
            throw LLMError.unsupportedCapabilities(requirements.requiredCapabilities)
        }
        if case .require(let modelID) = requirements.selectionPolicy {
            guard let requiredModel = plan.candidates.first(where: { $0.id == modelID }) else {
                throw LLMError.modelSelectionFailed("Required model \(modelID.rawValue) does not satisfy the current request or is unavailable in the active catalog.")
            }
            return ExecutionPlan(candidates: [requiredModel], requirements: requirements)
        }
        guard case .prefer(let preferred) = requirements.selectionPolicy,
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
