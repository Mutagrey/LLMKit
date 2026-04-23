# LLMExampleUI Responsibilities

- Provide an embeddable SwiftUI example screen.
- Compose catalog, lifecycle, orchestrator, UI, and backend adapters for demo use.
- Keep reusable UI modules backend-agnostic by placing backend-specific wiring only in this example target.
- Expose an Apple Intelligence first-run configuration.
- Surface downloadable example models in the Models tab without moving lifecycle logic out of `LLMUIDownloads`.
