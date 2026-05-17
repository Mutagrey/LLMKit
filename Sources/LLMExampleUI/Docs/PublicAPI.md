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

`LLMKitExampleConfiguration.liveHuggingFaceCatalog(...)` wires a lifecycle-owned live internet catalog backed by featured
Hugging Face MLX repositories into the example app, while keeping the same local fallback manifest for offline or failed
network cases.

`LLMKitExampleScreen` presents:

- Chat tab for sending prompts through the selected ready model, with a toolbar picker sheet limited to models whose backend availability is currently `.available`.
- Models tab for the full catalog, catalog source status, storage totals, and lifecycle-oriented card groups for ready, recommended, downloading, and available models.
- Settings tab for generation quality, routing mode, privacy mode, response token budget, and catalog source diagnostics.

The chat tab sets `ExecutionRequirements.allowsFallback` to `false` so demo-only backends do not silently answer when the
explicitly selected model is unavailable or fails.

`LLMKitExampleViewModel` persists the selected model plus routing preferences and output-token budget in `UserDefaults`.
After refresh it normalizes the selection to the first ready model, or clears it when no ready model exists, while keeping that state
inside the UI layer and the full catalog visible in Models.

Before manual chat sends and automated conversation runs, the example layer now performs a catalog and availability preflight
for the selected or participant-pinned models so strict demo selections fail early with model-specific diagnostics instead of a
generic runtime error later in the request path.
