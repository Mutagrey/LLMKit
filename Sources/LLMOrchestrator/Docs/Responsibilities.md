# LLMOrchestrator Responsibilities

Owns capability matching, backend selection, request normalization, fallback, and app-facing service composition. It does not perform raw HTTP, direct storage writes, UI rendering, or provider SDK calls.

Fallback is limited to selecting another already eligible `ModelDescriptor`; backend-specific retry, provider mapping, and transport recovery remain outside this module.
