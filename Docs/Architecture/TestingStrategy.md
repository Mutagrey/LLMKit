# Testing Strategy

Use focused Swift Testing tests. Start with domain invariants and protocol compile contracts, then add coordination behavior, orchestrator routing/fallback tests with fake backends, backend mapper tests, and optional UI state tests.

Architecture tests must guard module boundaries directly:

- `Package.swift` target dependencies must preserve the documented one-way graph.
- `Sources/**/*.swift` imports must not bypass target boundaries or leak backend/UI frameworks into lower layers.
- Every source target must keep the required module docs: `Overview.md`, `Responsibilities.md`, `PublicAPI.md`, `DependencyRules.md`, and `TODO.md`.

Runtime hardening tests should focus on stable public behavior, especially capability matching, routing order, fallback cancellation behavior, model lifecycle state isolation, and installed model record ordering.
