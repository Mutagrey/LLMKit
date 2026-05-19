# LLMOrchestrator Responsibilities

Owns capability matching, backend selection, request normalization, fallback, and app-facing service composition. It does not perform raw HTTP, direct storage writes, UI rendering, or provider SDK calls.

Fallback is limited to selecting another already eligible `ModelDescriptor`; backend-specific retry, provider mapping, and transport recovery remain outside this module. Cancellation and unsupported capability failures stop fallback.

When a backend emits backend-neutral tool requests, orchestration may execute them through `ToolService`, append tool result turns, and continue the conversation on the same selected model. Tool execution failures stop the round-trip instead of triggering backend fallback.

Safety policy evaluation is an orchestration concern: services may modify or deny input before backend selection and may
modify or deny final output before completion is emitted. Domain-specific persistence, metrics, prompts, and decision logic
remain outside this module.

For local execution, orchestration may request other local backends to unload cached model state through the optional
`BackendModelUnloading` hook before the selected candidate starts. The backends still own actual unload mechanics.
