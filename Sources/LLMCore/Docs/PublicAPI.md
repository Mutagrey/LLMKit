# LLMCore Public API

Public API is limited to stable value types and enums needed across targets.

Streaming helpers include `StreamedTextAccumulator`, a small value type for accumulating text deltas without duplicating ad hoc string state across modules.
