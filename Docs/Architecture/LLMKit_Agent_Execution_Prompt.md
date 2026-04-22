# LLMKit Agent Execution Prompt

Use `LLMKit_Master_Architecture_Blueprint.md` as the authoritative architecture source.

Your task is to scaffold and implement a modular Swift Package named `LLMKit` that serves as an AI runtime platform for Apple applications.

## Work mode

- Follow the master blueprint strictly.
- Do not improvise architecture outside the documented boundaries.
- Do not collapse modules together for convenience.
- Do not implement provider-specific logic outside backend adapter targets.
- Do not begin with feature code. Begin with package structure and documentation.

## Execution order

1. Create package tree and all targets.
2. Create root docs and ADRs.
3. Create per-module docs inside each target.
4. Create compile-safe public contracts and empty skeletons.
5. Implement core types and protocols.
6. Implement orchestration skeleton.
7. Implement lifecycle skeleton.
8. Implement backend skeletons.
9. Implement optional UI skeletons.
10. Add tests.
11. Incrementally fill in implementation details without breaking boundaries.

## Architectural rules

- Capability-driven routing.
- Async/await first.
- AsyncSequence / AsyncThrowingStream for streaming.
- Actor isolation for shared mutable state.
- Public APIs must remain backend-neutral.
- No singleton runtime.
- No god objects.
- No code duplication across backends.
- No UI logic inside runtime layers.
- No provider imports in app-facing modules.

## Expected result

The package must be ready to support:

- Apple Foundation Models
- local models via Core ML
- local models via MLX
- remote providers
- model families such as Qwen and Gemma
- reusable chat UI
- model download/install/warmup lifecycle
- structured output
- tool calling
- observability and safety hooks

## Quality bar

- Latest Swift language and Apple SDK practices where appropriate.
- Clear module boundaries.
- Minimal duplication.
- Small, focused types.
- Comprehensive documentation.
- Tests for contracts and orchestration behavior.

## Deliver incrementally

At the end of each major phase, ensure:

- code compiles
- docs match implementation
- dependencies remain valid
- no boundary violations were introduced

Do not optimize for speed of feature completion. Optimize for long-term package integrity.
