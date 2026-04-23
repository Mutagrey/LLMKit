# LLMUIChat Overview

`LLMUIChat` provides optional backend-agnostic SwiftUI chat presentation.

The view model can consume any `ChatService` and maps core chat stream events into presentation state without owning routing, transport, or backend details.

Tool lifecycle events are rendered as transcript items alongside regular chat messages, so the UI can show backend-neutral tool requests and completions without knowing provider-specific wire formats.
