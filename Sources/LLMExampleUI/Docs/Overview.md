# LLMExampleUI Overview

`LLMExampleUI` is an example composition layer for trying LLMKit from a SwiftUI app.

It wires the backend-agnostic chat and downloads UI to a lifecycle-owned catalog that can include Apple Intelligence through
`LLMBackendFoundationModels`, curated local MLX text models through `LLMBackendMLX`, or a signed dynamic internet catalog
through `LLMModelLifecycle.DynamicModelCatalog`.

The root example screen uses a tabbed SwiftUI shell with chat, model lifecycle, and settings tabs.
The chat tab exposes only ready chat models through a picker sheet so the reusable `LLMUIChat` surface can stay focused on transcript and composer behavior.
The Models tab remains the full catalog surface: it groups ready, recommended, downloading, and available models, surfaces install
progress inline, opens requirements and source metadata from an `info.circle` details affordance, and keeps download/delete/select
actions in lifecycle-oriented cards.
