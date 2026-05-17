# LLMUIChat Responsibilities

Owns chat rendering and UI state. It does not perform routing, transport, persistence, or backend-specific logic.

Tool request and completion rendering stays presentation-only; execution, policy, and backend mapping remain outside this module.

The optional pre-send validation hook is host-supplied state gating only; model selection diagnostics and catalog policy still remain outside this module.

The close hook may request backend runtime cleanup through `ChatService`, but it does not know which backend owns that state.
