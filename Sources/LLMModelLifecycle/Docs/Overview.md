# LLMModelLifecycle Overview

`LLMModelLifecycle` owns model discovery, install, verification, warmup, and eviction.

It now also owns manifest-backed catalog loading through `ManifestLoader`, curated manifest definitions for example/demo hosts,
catalog registration through `DefaultModelCatalog(manifest:)` plus manifest merge/replace operations, and
`DynamicModelCatalog` for signed internet-loaded catalogs with fallback to a local catalog.
Interrupted install handling also lives here through `ModelInstallInterruptionPolicy`, so cancellation cleanup and
resume behavior stay in the lifecycle layer rather than leaking into backends or UI.
