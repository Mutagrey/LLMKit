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

`LLMKitExampleConfiguration.dynamicRemoteManifest(remoteSource:)` wires `DynamicModelCatalog` into the example app so the
Models tab can refresh a signed internet catalog at runtime and fall back to the curated local catalog when fetch or
verification fails. The example view model also surfaces the catalog source status so the demo can show when it is using
the signed remote manifest versus a local fallback.

`LLMKitExampleScreen` presents:

- Chat tab for sending prompts through the selected model, with a toolbar-based model picker and compact reusable chat UI.
- Models tab for catalog source status, selected-model metadata, storage totals, and grouped model sections for in-progress installs, chat-ready models, installed-but-not-ready models, and downloadable models, with inline lifecycle controls including user-requested cancellation.
- Settings tab for generation quality, routing mode, privacy mode, response token budget, and catalog source diagnostics.

The chat tab sets `ExecutionRequirements.allowsFallback` to `false` so demo-only backends do not silently answer when the
explicitly selected model is unavailable or fails.

`LLMKitExampleViewModel` persists the selected model plus routing preferences and output-token budget in `UserDefaults`,
so the demo restores the previous selection and settings after app restart while keeping that state inside the UI layer.
