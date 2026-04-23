# LLMBackendFoundationModels Overview

`LLMBackendFoundationModels` adapts Apple Foundation Models to generic backend contracts.

The adapter probes `SystemLanguageModel` availability inside this backend target, loads backend-neutral model handles, and maps generic generation/chat requests to Foundation Models prompts and options.

When the Foundation Models framework is unavailable, the OS is too old, Apple Intelligence is disabled, the device is ineligible, or the model is not ready, the backend reports unavailable without leaking Apple SDK types to shared modules.
