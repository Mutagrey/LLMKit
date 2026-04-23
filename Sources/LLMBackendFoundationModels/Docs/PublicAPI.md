# LLMBackendFoundationModels Public API

Public API is limited to generic backend conformers and availability helpers.

`FoundationModelsBackend` conforms to `ModelBackend` for Apple Foundation Models descriptors.

`FoundationModelsRuntimeAvailability` lets host code override runtime availability for tests or app-specific gating. Without an override, the backend probes `SystemLanguageModel.default.availability` where the SDK and OS support it.
