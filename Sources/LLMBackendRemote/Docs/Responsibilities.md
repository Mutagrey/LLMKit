# LLMBackendRemote Responsibilities

Owns provider abstraction, request/response mapping, streaming adaptation, and error mapping. It does not expose provider DTOs.

Concrete provider integrations may add public configuration factories, but provider wire formats must remain private implementation details inside this module.

Provider integrations must fail explicitly when a core message or event shape cannot be represented without loss in that provider's wire format.

Provider error bodies may be decoded privately for diagnostics, but public errors must remain backend-neutral.
