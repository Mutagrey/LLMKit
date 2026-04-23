# ADR-008: Example UI Composition Target

## Status

Accepted

## Context

The reusable UI modules must remain backend-agnostic, but the package needs a concrete example UI that can verify Apple Intelligence/Foundation Models and later show downloadable local models.

## Decision

Add `LLMExampleUI` as a demo composition target. It may import concrete backend adapters and reusable UI modules so app-level wiring stays outside `LLMUIChat` and `LLMUIDownloads`.

The default configuration registers the system-managed Apple Intelligence descriptor and the Foundation Models backend. Downloadable model descriptors are injected separately until real Core ML or MLX manifests exist.

## Consequences

- `LLMUIChat` and `LLMUIDownloads` stay backend-agnostic.
- The example UI can be embedded by clients that want a quick smoke test.
- Architecture checks must treat `LLMExampleUI` as a demo composition target, not as a reusable runtime or UI layer.
