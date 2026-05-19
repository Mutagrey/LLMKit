# LLMUIChat Public API

Public API includes chat screen, view model, message rendering, and theme configuration.

`ChatScreen` renders a backend-agnostic transcript and compact composer using `ChatViewModel`, keeps the input docked with `safeAreaInset`, and exposes system keyboard dismissal affordances without owning model selection.

`ChatViewModel.submit(_:)` trims blank input, appends a user message, starts a managed streaming task, optionally runs a host-provided pre-send validation hook, forwards normalized `ChatRequest` values with its configured `ExecutionRequirements`, consumes `ChatService` streaming events, exposes in-flight streamed text, appends the assistant response, and surfaces tool lifecycle entries through backend-neutral transcript items.
When a host supplies `runtimeMetricsProvider`, new sanitized runtime telemetry emitted during the send is attached to the
assistant transcript item so `ChatMessageBubble` can render a compact metrics line below the message text.
Hosts may also supply `transientMessagesProvider` and `transientContextSignatureProvider` to prepend request-only
messages such as system prompts without displaying or persisting them. When the signature changes after a prior send,
`ChatViewModel` resets the backend chat session before submitting the next request.

`ChatViewModel.cancelStreaming()` cancels the in-flight task so host UI can expose an explicit stop button while a model is responding.

`ChatViewModel.close(resetRuntimeSession:)` cancels any active stream and, by default, asks the configured `ChatService`
to reset backend runtime state for the view model's `SessionID`. Hosts should call it from sheet dismissal or equivalent
surface teardown when they want retries to start from a clean native backend session.
