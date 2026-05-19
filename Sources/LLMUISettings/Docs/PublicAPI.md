# LLMUISettings Public API

Public API includes `LLMSettingsScreen`, `LLMSettingsContext`, `LLMSettingsScreenConfiguration`, `LLMSettingsActions`,
`LLMSettingsSection`, `LLMSettingsInfoRow`, and `LLMSettingsFormatting`.

Hosts pass a binding to `LLMRuntimeSettings`, optional selected-model/catalog/storage text, and closures for app-owned
actions such as opening model management, opening session management, resetting prompts, and applying runtime updates.
