# LLMBackendMLX Responsibilities

Owns MLX runtime integration and support matrices approved by ADR-009. It loads already-installed local model
directories and executes generation/chat through backend-neutral `ModelBackend` contracts. It also owns cleanup of
cached native MLX chat sessions for failed attempts and explicit host-driven session reset.

It does not download models, own catalog policy, perform routing, or implement multimodal input processing. VLM-capable
families may be declared in catalogs for future expansion, but the current backend treats them as text-only models.
