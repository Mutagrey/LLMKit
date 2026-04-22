# ADR-005: UI Isolation

Status: Accepted

Context: Reusable UI must work with any backend.

Decision: UI targets depend on public service contracts and domain state only.

Alternatives considered: UI-specific provider integrations.

Consequences: UI previews and tests use fake services; backend details stay hidden.

Migration / rollback plan: Replace backend imports in UI with protocol-based dependencies.
