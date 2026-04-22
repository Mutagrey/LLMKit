# ADR-003: Session Ownership

Status: Accepted

Context: Conversation state must not be duplicated across backends or UI.

Decision: Session state is backend-neutral. Persistence contracts live below session coordination.

Alternatives considered: Provider-native sessions exposed to app code.

Consequences: Backend adapters may maintain private runtime sessions, but public state stays stable.

Migration / rollback plan: Move any leaked provider session data behind adapter-owned mapping.
