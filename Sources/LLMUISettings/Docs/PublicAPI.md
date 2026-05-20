# LLMUISettings Public API

Public API includes `LLMSettingsScreen`, `LLMSettingsOverviewContent`, `LLMSettingsHubScreen`,
`LLMSettingsNavigationLink`, `LLMSettingsContext`, `LLMSettingsStorageSummary`, `LLMSettingsScreenConfiguration`,
`LLMSettingsActions`, `LLMSettingsSection`, `LLMSettingsInfoRow`, and `LLMSettingsFormatting`.

Hosts pass a binding to `LLMRuntimeSettings`, optional selected-model/catalog/storage text, and closures for app-owned
actions such as opening model management, opening session management, resetting prompts, and applying runtime updates.
Storage cleanup actions are host-owned async closures for clearing partial model artifacts, saved chats, and installed
models; the settings UI renders the controls, asks for confirmation before invoking destructive cleanup, and shows the
summary. Storage summaries use the shared `LLMUIStorage` stacked bar.

Use `LLMSettingsHubScreen` when a host app needs a top-level settings hub with custom sections. Keep domain-specific
screens in the host app and link to `LLMSettingsScreen` for shared runtime controls.
