# LLMExampleUI Public API

- `LLMKitExampleScreen`
- `LLMKitExampleConfiguration`
- `LLMKitExampleModels`
- `LLMKitExampleViewModel`

The default `LLMKitExampleScreen()` uses `LLMKitExampleConfiguration.localIPhoneCatalog()` and can be embedded in an app scene.

`LLMKitExampleConfiguration.localIPhoneCatalog()` composes the lifecycle-owned curated manifest of Apple Intelligence plus
multiple iPhone-oriented local MLX text models.

`LLMKitExampleConfiguration.localQwenSmokeTest()` keeps the narrower single-model configuration for smoke tests.

`LLMKitExampleConfiguration.remoteManifest(_:)` loads a remote `ModelManifest` through `LLMModelLifecycle.ManifestLoader`
and builds the example composition from that manifest without moving manifest logic into UI.

`LLMKitExampleScreen` presents:

- Chat tab for sending prompts through the selected model, with a toolbar-based model picker and compact reusable chat UI.
- Models tab for catalog status, selected-model metadata, readiness grouping, and inline lifecycle/download controls.
- Settings tab for generation quality, routing mode, privacy mode, and response token budget.
