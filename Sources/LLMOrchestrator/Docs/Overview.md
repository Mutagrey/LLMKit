# LLMOrchestrator Overview

`LLMOrchestrator` owns runtime composition, routing, planning, fallback, and service façades.

Current services build an execution plan from catalog models, prioritize a requested preferred model when it satisfies the requirements, verify backend availability before execution, and try remaining candidates when an earlier backend is missing, unavailable, or fails before completion.

`ExecutionPlanner` applies backend-neutral device constraints before candidate ordering. Models whose declared
RAM class clearly exceeds the current `DeviceProfile` are filtered out before routing, with tolerance for devices
that report slightly less than their marketed RAM class. GGUF/llama.cpp descriptors are not rejected by declared
RAM class because mmap-backed loading makes that metadata too coarse for runtime eligibility. Declared free-disk
requirements remain lifecycle/install constraints so an already installed local model is not rejected just because
free space dropped after download.
When enabled by the caller, the planner can also apply `LocalRuntimeMemoryGuard` to local Core ML, MLX, and llama.cpp
candidates before backend load. This process-memory check is opt-in because the signal is volatile and can be too
strict for chat/session creation. GGUF/llama.cpp model files are treated as mmap-backed artifacts for this preflight,
so routing estimates request context and working memory without requiring the whole `.gguf` file to fit in
process-resident memory.
Before executing a local candidate, `BackendRegistry` asks other local backends that support `BackendModelUnloading`
to release loaded models so GGUF, MLX, and Core ML caches do not remain resident together.

Default generation and chat services can apply backend-neutral safety policy decisions before input reaches a backend and
before final output is returned. Structured generation supports prompt-validated JSON with one repair attempt so local
models can be routed without claiming native structured-output capability.
