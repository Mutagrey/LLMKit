# ADR-010: llama.cpp GGUF Backend

Status: Accepted

Context: LLMKit needs native GGUF text-generation support without folding llama.cpp runtime details into core,
orchestration, lifecycle, MLX, or UI targets. GGUF is not an MLX safetensors format and must be treated as a
separate local backend.

Decision: Add a dedicated `LLMBackendLlamaCpp` target for llama.cpp-backed GGUF text completion and chat. Keep
download, install, verification, and catalog ownership in `LLMModelLifecycle`; GGUF models are ordinary
`ModelArtifact` values whose `relativePath` ends in `.gguf`. The backend owns only model loading, streaming
generation, unload, cancellation cleanup, and llama.cpp-specific prompt/runtime mapping.

The target vendors the official llama.cpp XCFramework boundary built from the upstream SwiftUI example workflow and
links it only into `LLMBackendLlamaCpp`. If the binary module is removed or cannot be imported, the backend reports
that the native runtime is unavailable rather than pretending to run GGUF files.

Alternatives considered:
- Add GGUF to `LLMBackendMLX`. Rejected because MLX and GGUF use different runtime and model formats.
- Use a local llama-server bridge. Rejected for package runtime v1 because it is not an iOS-native backend.
- Add a broken binary target path now. Rejected because it would make the package fail to resolve before the
  XCFramework exists.

Consequences:
- `BackendKind.llamaCpp` becomes the routing identity for native GGUF models.
- `LLMBackendLlamaCpp` is the only target allowed to import or wrap llama.cpp native APIs.
- `Vendor/llama.cpp/llama.xcframework` is a checked-in binary runtime artifact and `Vendor/llama.cpp/COMMIT`
  records the upstream revision used to build it.
- Initial public scope is text completion, chat, and streaming only. Tools, embeddings, multimodal input, grammar
  constraints, and structured-output enforcement remain out of scope until separate phases define them.

Migration / rollback plan:
- Remove the `LLMBackendLlamaCpp` product and descriptors if native packaging is abandoned.
- Existing MLX, Core ML, Foundation Models, remote, lifecycle, and UI targets remain unaffected because they do not
  depend on this backend.
