# LLMBackendRemote Responsibilities

Owns provider abstraction, request/response mapping, streaming adaptation, and error mapping. It does not expose provider DTOs.

Concrete provider integrations may add public configuration factories, but provider wire formats must remain private implementation details inside this module.
