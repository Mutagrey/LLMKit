# LLMUIChat Overview

`LLMUIChat` provides optional backend-agnostic SwiftUI chat presentation with a compact transcript and composer tuned for long-running chat sessions.

The view model can consume any `ChatService` and maps core chat stream events into presentation state without owning routing, transport, or backend details.

Tool lifecycle events are rendered as transcript items alongside regular chat messages, so the UI can show backend-neutral tool requests and completions without knowing provider-specific wire formats.
The composer owns focus and keyboard-dismiss behavior only; it does not move routing, policy, or model selection into the reusable chat module.
Assistant bubbles can display a compact runtime metrics line when the host wires sanitized telemetry from a metrics sink.
