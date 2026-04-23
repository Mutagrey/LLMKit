# LLMUIChat Public API

Public API includes chat screen, view model, message rendering, and theme configuration.

`ChatScreen` renders a backend-agnostic transcript and composer using `ChatViewModel`.

`ChatViewModel.send(_:)` trims blank input, appends a user message, forwards normalized `ChatRequest` values with its configured `ExecutionRequirements`, consumes `ChatService` streaming events, exposes in-flight streamed text, and appends the assistant response.
