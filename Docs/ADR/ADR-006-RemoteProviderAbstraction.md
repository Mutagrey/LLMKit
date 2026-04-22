# ADR-006: Remote Provider Abstraction

Status: Accepted

Context: Remote providers differ in wire format, streaming details, and auth.

Decision: `LLMBackendRemote` hides provider DTOs behind generic backend contracts and uses `LLMNetworking` for transport.

Alternatives considered: Exposing provider-native request and response types.

Consequences: Mapping code is isolated and public APIs remain provider-neutral.

Migration / rollback plan: Move provider-specific types into backend-internal files.
