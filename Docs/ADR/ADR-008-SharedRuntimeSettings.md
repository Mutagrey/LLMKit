# ADR-008: Shared Runtime Settings

## Status

Accepted

## Context

Demo apps and host apps need the same runtime controls for routing, context windows, output limits, local memory, MLX, and
GGUF execution. Keeping those defaults in each app creates drift and makes new backend knobs hard to expose consistently.

## Decision

Add `LLMSettings` for backend-neutral settings values, presets, constraints, normalization, and persistence helpers. Add
`LLMUISettings` for SwiftUI presentation of those values. Backend-specific mapping remains in backend targets or host
adapters.

## Consequences

- Apps share one settings schema and grouped settings UI.
- Backend SDK details still do not leak into core or UI modules.
- Backend targets may depend on `LLMSettings` for mapping helpers, but `LLMSettings` must not depend on backend modules.
