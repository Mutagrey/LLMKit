# LLMKitDemo

Minimal iOS demo app for running LLMKit on a simulator or physical device.

Open `LLMKitDemo.xcodeproj`, select the `LLMKitDemo` scheme, choose a device, and run. For a physical device, set your signing team in Xcode if needed.

The demo app owns its tabbed SwiftUI shell and composes:

- Apple Intelligence through the Foundation Models backend when the OS and device support it.
- A live featured MLX catalog from Hugging Face by default, with the curated local MLX catalog as fallback.
- A signed dynamic internet catalog when these scheme environment variables are set:
  `LLMKIT_REMOTE_CATALOG_URL`, `LLMKIT_REMOTE_CATALOG_SIGNATURE`, and `LLMKIT_REMOTE_CATALOG_PUBLIC_KEY`.
- Model and settings tabs that exercise the same lifecycle and orchestration-facing UI used by package clients.
- A Skills tab for editing reusable system-prompt skills. New manual chats copy the default skill combination, while each
  chat can override its main and additional skills from the chat header.
- A compact manual-chat header with selected model, selected skills, free RAM, and per-response runtime metrics when local
  backends emit sanitized telemetry.
