import LLMCore
import LLMOrchestrator
import LLMProtocols

struct DemoModelPreflight {
    let catalog: any ModelCatalogProviding
    let catalogStatusProvider: (any ModelCatalogStatusProviding)?
    let backends: [any ModelBackend]
    private let planner = ExecutionPlanner()

    func validate(
        _ requirements: ExecutionRequirements,
        context: String
    ) async throws -> ModelDescriptor {
        let models = try await catalog.availableModels()
        let status = await catalogStatusProvider?.catalogStatus() ?? .local
        let plan = planner.plan(models: models, requirements: requirements)

        switch requirements.selectionPolicy {
        case .require(let modelID):
            guard let descriptor = models.first(where: { $0.id == modelID }) else {
                throw LLMError.modelSelectionFailed(
                    "\(context): required model \(modelID.rawValue) is not present in the active catalog (\(catalogDescription(status)))."
                )
            }
            guard plan.candidates.contains(where: { $0.id == modelID }) else {
                throw LLMError.modelSelectionFailed(
                    "\(context): required model \(modelID.rawValue) is present in the active catalog but filtered out by the current request or device constraints. Required capabilities: \(capabilityList(requirements.requiredCapabilities)). Model capabilities: \(capabilityList(descriptor.capabilities)). Active catalog: \(catalogDescription(status))."
                )
            }
            let availability = await availability(for: descriptor)
            guard availability.status == .available else {
                throw LLMError.modelSelectionFailed(
                    "\(context): required model \(modelID.rawValue) is in the active catalog but unavailable. Availability: \(availabilityDescription(availability)). Active catalog: \(catalogDescription(status))."
                )
            }
            return descriptor

        case .prefer(let modelID):
            if let preferred = plan.candidates.first(where: { $0.id == modelID }) {
                let availability = await availability(for: preferred)
                if availability.status == .available {
                    return preferred
                }
            }
            guard let candidate = await firstAvailableCandidate(in: plan.candidates) else {
                throw LLMError.modelSelectionFailed(
                    "\(context): preferred model \(modelID.rawValue) is not currently usable and no fallback model is available in the active catalog (\(catalogDescription(status)))."
                )
            }
            return candidate

        case .automatic:
            guard let candidate = await firstAvailableCandidate(in: plan.candidates) else {
                throw LLMError.modelSelectionFailed(
                    "\(context): no available model satisfies the current request in the active catalog (\(catalogDescription(status)))."
                )
            }
            return candidate
        }
    }

    func validate(
        definition: AutomatedConversationDefinition,
        executionRequirements: ExecutionRequirements,
        context: String
    ) async throws {
        let baseRequirements = definition.sharedExecutionRequirements ?? executionRequirements
        _ = try await validate(baseRequirements, context: "\(context) shared model")

        for participant in definition.participants {
            let participantRequirements = baseRequirements.updating(
                requiredCapabilities: baseRequirements.requiredCapabilities.union([.chat]),
                selectionPolicy: participant.selectionPolicy ?? baseRequirements.selectionPolicy,
                preferredLatency: .background
            )
            _ = try await validate(
                participantRequirements,
                context: "\(context) participant \(participant.displayName)"
            )
        }
    }

    private func firstAvailableCandidate(in candidates: [ModelDescriptor]) async -> ModelDescriptor? {
        for candidate in candidates {
            let availability = await availability(for: candidate)
            if availability.status == .available {
                return candidate
            }
        }
        return nil
    }

    private func availability(for descriptor: ModelDescriptor) async -> BackendAvailability {
        guard let backend = backends.first(where: { $0.backendKind == descriptor.backend }) else {
            return BackendAvailability(status: .unavailable(reason: "Backend adapter is not configured."))
        }
        return await backend.availability(for: descriptor)
    }

    private func availabilityDescription(_ availability: BackendAvailability) -> String {
        switch availability.status {
        case .available:
            return "available"
        case .unavailable(let reason):
            return reason
        case .requiresInstall:
            return "install required"
        case .requiresNetwork:
            return "network required"
        case .unsupported:
            return "unsupported"
        }
    }

    private func catalogDescription(_ status: ModelCatalogStatus) -> String {
        let source = status.source.rawValue
        guard let message = status.message, !message.isEmpty else {
            return source
        }
        return "\(source): \(message)"
    }

    private func capabilityList(_ capabilities: Set<ModelCapability>) -> String {
        guard !capabilities.isEmpty else {
            return "none"
        }
        return capabilities.map { String(describing: $0) }.sorted().joined(separator: ", ")
    }
}
