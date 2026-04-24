# LLMProtocols Public API

Public API is protocol-oriented and reuses `LLMCore` domain types.

Backend request wrappers preserve the full backend-neutral `GenerationRequest`, including optional structured output
schema metadata, so adapters can choose native structured APIs or prompt-level fallback without changing public service contracts.

Catalog-facing UI can optionally depend on `ModelCatalogStatusProviding` to surface whether a backend-neutral catalog is
local, signed remote, or falling back after verification or fetch failures.
