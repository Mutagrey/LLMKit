# LLMBackendFoundationModels Overview

`LLMBackendFoundationModels` adapts Apple Foundation Models to generic backend contracts.

The adapter probes `SystemLanguageModel` availability inside this backend target, loads backend-neutral model handles, and maps generic generation/chat requests to Foundation Models prompts and options.

Chat prompt mapping preserves backend-neutral tool context by folding available tool definitions into instructions and explicit tool result messages into the prompt transcript when native Foundation Models tool APIs are not in use.

For generation requests that carry a backend-neutral `StructuredOutputSchema`, the adapter attempts to map that schema
to Foundation Models guided generation with `GenerationSchema`. When mapping succeeds, the backend returns the
generated structured content as JSON text to preserve the package's backend-neutral response shape.

When the Foundation Models framework is unavailable, the OS is too old, Apple Intelligence is disabled, the device is ineligible, or the model is not ready, the backend reports unavailable without leaking Apple SDK types to shared modules.
