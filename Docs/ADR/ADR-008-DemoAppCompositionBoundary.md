# ADR-008: Demo App Composition Boundary

## Status

Accepted

## Context

The reusable UI modules must remain backend-agnostic, but the package needs a concrete example UI that can verify Apple Intelligence/Foundation Models and later show downloadable local models.

## Decision

Keep demo composition inside `Examples/LLMKitDemo/LLMKitDemo` instead of publishing a separate `LLMExampleUI` package target. The demo app may import concrete backend adapters and reusable UI modules so app-level wiring stays outside `LLMUIChat` and `LLMUIModels`.

The default demo configuration registers the system-managed Apple Intelligence descriptor, the Foundation Models backend, and the MLX lifecycle-backed catalog used by the sample app.

## Consequences

- `LLMUIChat` and `LLMUIModels` stay backend-agnostic.
- The package no longer exposes demo UI as public API.
- Architecture checks only cover package targets; the demo app remains an app-level integration surface.
