# LLMOrchestrator Overview

`LLMOrchestrator` owns runtime composition, routing, planning, fallback, and service façades.

Current services build an execution plan from catalog models, prioritize a requested preferred model when it satisfies the requirements, verify backend availability before execution, and try remaining candidates when an earlier backend is missing, unavailable, or fails before completion.

`ExecutionPlanner` now also applies backend-neutral device constraints before candidate ordering. Models whose
declared RAM or free-disk requirements exceed the current `DeviceProfile` or `RuntimeConstraints` are filtered
out before routing, keeping iPhone-oriented catalogs usable without leaking UI heuristics into runtime services.
