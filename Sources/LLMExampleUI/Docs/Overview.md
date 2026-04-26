# LLMExampleUI Overview

`LLMExampleUI` is an example composition layer for trying LLMKit from a SwiftUI app.

It wires the backend-agnostic chat and downloads UI to a lifecycle-owned catalog that can include Apple Intelligence through
`LLMBackendFoundationModels`, curated local MLX text models through `LLMBackendMLX`, or a signed dynamic internet catalog
through `LLMModelLifecycle.DynamicModelCatalog`.

The root example screen uses a `TabView` with chat, model lifecycle, and settings tabs.
The chat tab keeps model selection in the top toolbar so the reusable `LLMUIChat` surface can stay focused on transcript and composer behavior, while sharing the same lifecycle-backed status text used by the Models tab.
When configured with a curated or dynamic catalog, the Models tab shows one universal card per model, surfaces install progress inline,
opens requirements and source metadata from an `info.circle` details affordance, and keeps delete actions for installed downloadable
models behind list swipe actions.
