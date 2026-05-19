# LLMProtocols Responsibilities

Owns contracts between app-facing services and implementations. It may define narrow cleanup hooks for backend-owned
runtime state, such as resetting cached native chat sessions by `SessionID` or unloading local model caches before
another local backend runs.

It does not implement routing, persistence, UI, networking, or backend SDK calls.
