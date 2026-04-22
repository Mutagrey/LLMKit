# LLMUIChat Public API

Public API includes chat screen, view model, message rendering, and theme configuration.

`ChatViewModel.send(_:)` appends a user message, consumes `ChatService` streaming events, and appends the assistant response.
