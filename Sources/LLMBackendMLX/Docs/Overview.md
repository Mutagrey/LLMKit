# LLMBackendMLX Overview

`LLMBackendMLX` is the MLX-backed local model adapter.

The adapter gates availability on supported model families, explicit host-provided runtime availability, and already-installed
model files. Qwen and Gemma descriptors, including VLM-tagged descriptors, can be present in catalogs, but this runtime path
currently executes only text `chat` and `completion` requests.
