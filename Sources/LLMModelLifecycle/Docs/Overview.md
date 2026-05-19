# LLMModelLifecycle Overview

`LLMModelLifecycle` owns model discovery, install, verification, warmup, and eviction.

It now also owns manifest-backed catalog loading through `ManifestLoader`, curated manifest definitions for example/demo hosts,
catalog registration through `DefaultModelCatalog(manifest:)` plus manifest merge/replace operations, and
`DynamicModelCatalog` for signed internet-loaded catalogs with fallback to a local catalog.
The curated iPhone MLX text catalog is intentionally small and capped to descriptors with RAM requirements at or below
8 GB, including only the practical uncensored/abliterated variants for iPhone-class local MLX execution.
Native GGUF Llama, Qwen, and Gemma descriptors are exposed in a separate curated manifest so host apps can make GGUF the
primary local catalog without mixing llama.cpp runtime concerns into MLX catalog entries.
Interrupted install handling also lives here through `ModelInstallInterruptionPolicy`, so cancellation cleanup and
resume behavior stay in the lifecycle layer rather than leaking into backends or UI. The default cancellation policy
preserves verified artifacts and downloader resume cache for retry and reports a paused install state; eager cancellation
cleanup is an explicit policy choice.
The install coordinator performs lifecycle-owned free-space preflight and the default artifact downloader retries transient
URLSession failures with resume data while keeping cached resume state out of UI and backend modules.
Remote catalog trust controls also live here through `RemoteManifestTrustPolicy`, including HTTPS enforcement, host
allowlisting, and trusted signing-key pinning for internet-loaded manifests.
