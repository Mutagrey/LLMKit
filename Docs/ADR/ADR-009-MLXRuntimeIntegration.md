# ADR-009: MLX Runtime Integration

Status: Accepted

Context: `LLMBackendMLX` must execute downloaded local models without leaking MLX SDK types into core,
coordination, lifecycle, orchestration, or UI targets. MLX Swift LM 3.x separates model execution from
downloader and tokenizer integrations.

Decision: Add `mlx-swift-lm` only to `LLMBackendMLX`, using `MLXLLM` and `MLXLMCommon` for local model
loading and generation. Use `MLXHuggingFace` plus `swift-transformers` `Tokenizers` only for tokenizer
loading from already-downloaded local model directories. Keep model artifact download ownership in
`LLMModelLifecycle`.

Alternatives considered:
- Import MLX directly in orchestration or lifecycle. Rejected because it leaks backend runtime concerns.
- Use Hugging Face download APIs in `LLMBackendMLX`. Rejected because download/install state belongs to
  `LLMModelLifecycle`.
- Keep MLX as a skeleton. Rejected for this phase because local smoke-test execution now needs a real backend.

Consequences:
- `LLMBackendMLX` becomes the only target that imports MLX runtime packages.
- SwiftPM/Xcode must resolve MLX Swift LM and tokenizer dependencies before building the full package.
- `LLMModelLifecycle` remains responsible for downloading and recording installed state.

Migration / rollback plan:
- Revert `LLMBackendMLX` package products and restore the skeleton backend if MLX runtime compatibility regresses.
- Keep `ModelDescriptor.source` and lifecycle artifact download support; those remain backend-neutral.
