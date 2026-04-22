# Layer Rules

- `LLMCore` imports Foundation only.
- `LLMProtocols` imports `LLMCore` only.
- Coordination modules remain backend-neutral.
- `LLMOrchestrator` routes through protocols and coordination modules.
- Backend adapters do not import UI or each other.
- UI modules consume public services only.
- Model lifecycle does not execute prompts.
