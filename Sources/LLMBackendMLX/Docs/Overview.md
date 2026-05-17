# LLMBackendMLX Overview

`LLMBackendMLX` is the MLX-backed local model adapter.

The adapter gates availability on supported model families, explicit host-provided runtime availability, and already-installed
model files. Qwen and Gemma descriptors, including VLM-tagged descriptors, can be present in catalogs, but this runtime path
currently executes only text `chat` and `completion` requests. Streamed text is normalized inside the adapter so MLX chat
template control tokens such as `"<end_of_turn>"` do not leak into backend-neutral chat transcripts.

Chat requests are mapped to native `MLXLMCommon.Chat.Message` values instead of flattened `role: text` prompts. When a
`SessionID` is provided, the runtime keeps an isolated MLX `ChatSession` per model/session pair and rehydrates it from the
backend-neutral message history if the caller snapshot changes.

Cached MLX `ChatSession` values are reset when a chat attempt fails or is cancelled, and can also be reset explicitly by
`SessionID` when a host chat surface closes.
