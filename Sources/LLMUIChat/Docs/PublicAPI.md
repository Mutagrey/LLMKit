# LLMUIChat Public API

Public API includes chat screen, view model, message rendering, and theme configuration.

`ChatScreen` renders a backend-agnostic transcript and compact composer using `ChatViewModel`, keeps the input docked with `safeAreaInset`, and exposes system keyboard dismissal affordances without owning model selection.

`ChatViewModel.submit(_:)` trims blank input, appends a user message, starts a managed streaming task, optionally runs a host-provided pre-send validation hook, forwards normalized `ChatRequest` values with its configured `ExecutionRequirements`, consumes `ChatService` streaming events, exposes in-flight streamed text, appends the assistant response, and surfaces tool lifecycle entries through backend-neutral transcript items.

`ChatViewModel.cancelStreaming()` cancels the in-flight task so host UI can expose an explicit stop button while a model is responding.
