# LLMUIChat Overview

`LLMUIChat` provides optional backend-agnostic SwiftUI chat presentation with a compact transcript, inline navigation title, and safe-area composer tuned for long-running chat sessions.

The view model can consume any `ChatService` and maps core chat stream events into presentation state without owning routing, transport, or backend details.

Tool lifecycle events are rendered as transcript items alongside regular chat messages, so the UI can show backend-neutral tool requests and completions without knowing provider-specific wire formats.
The composer owns focus, keyboard-dismiss behavior, and the send affordance only; generation progress is shown in the transcript below the latest bubble instead of inside the input panel.
Assistant bubbles can display a compact runtime metrics line when the host wires sanitized telemetry from a metrics sink.
Hosts can prepend transient request-only messages, such as a composed system prompt, without adding those messages to the
visible transcript or persisted chat history.
