# LLMSettings Public API

Public API includes `LLMRuntimeSettings`, `LLMSettingsConstraints`, `LLMSettingsNormalizer`, `LLMSettingsPreset`,
`LLMEffectiveSettings`, `LLMGPUOffloadPolicy`, `LLMIntegerSettingBounds`, and `LLMRuntimeSettingsPersistence`.

`LLMSettingsNormalizer` clamps user settings to package defaults and selected-model context limits. It also computes
effective input/output budgets and low-memory clamps without knowing which backend will execute the request.

Backend-specific adapters may map `LLMRuntimeSettings` into runtime-native options, but backend-specific types must not
appear in this module.
