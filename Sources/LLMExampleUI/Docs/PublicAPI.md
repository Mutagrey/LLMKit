# LLMExampleUI Public API

- `LLMKitExampleScreen`
- `LLMKitExampleConfiguration`
- `LLMKitExampleModels`
- `LLMKitExampleViewModel`

The default `LLMKitExampleScreen()` uses `LLMKitExampleConfiguration.appleIntelligenceOnly()` and can be embedded in an app scene.

`LLMKitExampleConfiguration.localQwenSmokeTest()` adds the downloadable MLX Qwen2.5 0.5B 4-bit descriptor so previews
and demo hosts can exercise model lifecycle UI before real MLX inference is enabled.

`LLMKitExampleScreen` presents:

- Chat tab for sending prompts through the selected model.
- Models tab for catalog status, selected-model metadata, and inline lifecycle/download controls.
- Settings tab for generation quality, routing mode, privacy mode, and response token budget.
