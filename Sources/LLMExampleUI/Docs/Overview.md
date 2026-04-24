# LLMExampleUI Overview

`LLMExampleUI` is an example composition layer for trying LLMKit from a SwiftUI app.

It wires the backend-agnostic chat and downloads UI to a lifecycle-owned catalog that can include Apple Intelligence through
`LLMBackendFoundationModels` and curated local MLX text models through `LLMBackendMLX`.

The root example screen uses a `TabView` with chat, model lifecycle, and settings tabs.
The chat tab keeps model selection in the top toolbar so the reusable `LLMUIChat` surface can stay focused on transcript and composer behavior.
When configured with the curated iPhone catalog, the Models tab groups ready models separately from installable models, keeps model
selection as compact checkmarked rows, and moves detailed requirements and source metadata into a model detail view.
