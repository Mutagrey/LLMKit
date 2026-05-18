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
        if case .require(let modelID) = requirements.selectionPolicy {
            guard let descriptor = models.first(where: { $0.id == modelID }) else {
                throw LLMError.modelSelectionFailed("Required model \(modelID.rawValue) is not present in the active catalog.")
            }

            let reasons = planner.rejectionReasons(for: descriptor, requirements: requirements)
            guard reasons.isEmpty else {
                throw LLMError.modelSelectionFailed("Required model \(modelID.rawValue) cannot be selected: \(reasons.joined(separator: "; ")).")
            }
        }

        let plan = planner.plan(models: models, requirements: requirements)
        guard !plan.candidates.isEmpty else {
            if case .require(let modelID) = requirements.selectionPolicy {
                throw LLMError.modelSelectionFailed("Required model \(modelID.rawValue) was not returned by the execution planner.")
            }
            throw LLMError.unsupportedCapabilities(requirements.requiredCapabilities)
        }
        if case .require(let modelID) = requirements.selectionPolicy {
            guard let requiredModel = plan.candidates.first(where: { $0.id == modelID }) else {
                throw LLMError.modelSelectionFailed("Required model \(modelID.rawValue) was not returned by the execution planner.")
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
