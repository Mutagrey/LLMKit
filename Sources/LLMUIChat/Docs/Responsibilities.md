# LLMUIChat Responsibilities

Owns chat rendering and UI state. It does not perform routing, transport, persistence, or backend-specific logic.

Tool request and completion rendering stays presentation-only; execution, policy, and backend mapping remain outside this module.
