# ADR-002: Capability-Driven Routing

Status: Accepted

Context: Apps should request capabilities rather than choose concrete providers.

Decision: Routing operates on `ModelCapability`, execution requirements, and model descriptors.

Alternatives considered: Provider enums in app-facing APIs.

Consequences: Backends remain replaceable and model families can move between runtimes.

Migration / rollback plan: Add capability metadata rather than provider-specific request surfaces.
