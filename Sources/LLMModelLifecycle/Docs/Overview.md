# LLMModelLifecycle Overview

`LLMModelLifecycle` owns model discovery, install, verification, warmup, and eviction.

It now also owns manifest-backed catalog loading through `ManifestLoader`, curated manifest definitions for example/demo hosts,
and catalog registration through `DefaultModelCatalog(manifest:)` plus manifest merge/replace operations.
