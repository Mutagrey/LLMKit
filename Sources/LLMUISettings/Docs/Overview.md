# LLMUISettings Overview

`LLMUISettings` renders backend-neutral SwiftUI settings for LLM runtime configuration.

`LLMSettingsScreen` presents a compact overview plus card-style navigation into model/routing, context, output, local
memory, MLX, GGUF, safety, storage, and reset controls while using only shared settings values and host-provided
presentation context.

`LLMSettingsHubScreen` and `LLMSettingsNavigationLink` provide the same card navigation shell for host apps that need to
mix shared runtime settings with app-specific settings such as prompts, safety text, model policy, or session management.
