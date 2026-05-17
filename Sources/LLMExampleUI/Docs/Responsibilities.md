# LLMExampleUI Responsibilities

- Provide an embeddable SwiftUI example screen.
- Compose catalog, lifecycle, orchestrator, UI, and backend adapters for demo use.
- Compose demo-only session persistence and automated conversation helpers without leaking those dependencies into reusable UI modules.
- Keep reusable UI modules backend-agnostic by placing backend-specific wiring only in this example target.
- Expose an Apple Intelligence first-run configuration.
- Surface downloadable example models in the Models tab with package UI from `LLMUIDownloads` without moving lifecycle logic back into
  the example target.
- Keep chat model selection limited to models that are currently ready to use, while preserving the complete catalog in Models.
