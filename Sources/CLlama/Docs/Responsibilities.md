# CLlama Responsibilities

- Provide a stable C module surface for llama.cpp headers.
- Keep the native header import separate from the Swift backend adapter.
- Avoid owning model loading, routing, lifecycle, or UI behavior.
