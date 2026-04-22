# ADR-007: MLX Backend Status

Status: Accepted

Context: MLX support may require external packages and model-family-specific maturity decisions.

Decision: Keep `LLMBackendMLX` as a skeleton without third-party dependencies until a dedicated ADR approves runtime integration.

Alternatives considered: Adding MLX Swift immediately.

Consequences: The target can compile as unsupported while preserving the package graph.

Migration / rollback plan: Add MLX dependencies only with an ADR that documents alternatives and rollback.
