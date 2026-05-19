# LLMUISettings Public API

Public API includes `LLMSettingsScreen`, `LLMSettingsHubScreen`, `LLMSettingsNavigationLink`, `LLMSettingsContext`,
`LLMSettingsScreenConfiguration`, `LLMSettingsActions`, `LLMSettingsSection`, `LLMSettingsInfoRow`, and
`LLMSettingsFormatting`.

Hosts pass a binding to `LLMRuntimeSettings`, optional selected-model/catalog/storage text, and closures for app-owned
actions such as opening model management, opening session management, resetting prompts, and applying runtime updates.

Use `LLMSettingsHubScreen` when a host app needs a top-level settings hub with custom sections. Keep domain-specific
screens in the host app and link to `LLMSettingsScreen` for shared runtime controls.
