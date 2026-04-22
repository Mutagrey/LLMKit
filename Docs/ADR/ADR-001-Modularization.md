# ADR-001: Modularization

Status: Accepted

Context: LLMKit must support multiple runtimes, providers, and UI layers without architectural sprawl.

Decision: Use separate SwiftPM targets for domain types, protocols, coordination modules, orchestration, backend adapters, and UI.

Alternatives considered: A single package target, or provider-first modules.

Consequences: More targets and docs are required, but layer boundaries are explicit and testable.

Migration / rollback plan: Collapse only if a future ADR proves a target has no independent responsibility.
