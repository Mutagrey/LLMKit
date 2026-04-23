# LLMExampleUI Overview

`LLMExampleUI` is an example composition layer for trying LLMKit from a SwiftUI app.

It wires the backend-agnostic chat and downloads UI to a small catalog that includes Apple Intelligence through `LLMBackendFoundationModels`.

The root example screen uses a `TabView` with chat, model lifecycle, and settings tabs.
When configured with downloadable descriptors such as the Qwen MLX smoke-test model, the Models tab surfaces inline metadata and
download progress for the selected model so preview/demo hosts can validate the install flow without a dedicated app shell.
