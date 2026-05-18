# LLMBackendLlamaCpp Overview

`LLMBackendLlamaCpp` is the isolated backend adapter for native llama.cpp GGUF text models.

The target is intentionally separate from `LLMBackendMLX` because GGUF and MLX safetensors are different runtime
formats. Model discovery and downloads remain owned by `LLMModelLifecycle`.
