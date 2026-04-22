# ADR-004: Model Lifecycle Separation

Status: Accepted

Context: Download/install/update/eviction concerns have different policies and failure modes than inference.

Decision: `LLMModelLifecycle` owns model lifecycle; `LLMOrchestrator` owns prompt execution decisions.

Alternatives considered: A combined runtime manager.

Consequences: UI can show lifecycle independently and inference code stays focused.

Migration / rollback plan: Move lifecycle behavior out of orchestration if it appears there.
