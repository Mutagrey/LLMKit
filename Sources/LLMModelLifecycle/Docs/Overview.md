# LLMModelLifecycle Overview

`LLMModelLifecycle` owns model discovery, install, verification, warmup, and eviction.

It now also owns manifest-backed catalog loading through `ManifestLoader`, curated manifest definitions for example/demo hosts,
catalog registration through `DefaultModelCatalog(manifest:)` plus manifest merge/replace operations, and
`DynamicModelCatalog` for signed internet-loaded catalogs with fallback to a local catalog.
Interrupted install handling also lives here through `ModelInstallInterruptionPolicy`, so cancellation cleanup and
resume behavior stay in the lifecycle layer rather than leaking into backends or UI.
The install coordinator performs lifecycle-owned free-space preflight and the default artifact downloader retries transient
URLSession failures with resume data while keeping cached resume state out of UI and backend modules.
Remote catalog trust controls also live here through `RemoteManifestTrustPolicy`, including HTTPS enforcement, host
allowlisting, and trusted signing-key pinning for internet-loaded manifests.
