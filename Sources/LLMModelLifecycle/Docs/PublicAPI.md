# LLMModelLifecycle Public API

Public API includes manifests, catalog, installer, installed record persistence, and install state machine support.

`CuratedModelManifests` exposes lifecycle-owned `ModelManifest` values for Apple system models and iPhone-oriented local MLX text
models so host apps can build catalogs without hardcoding descriptors in UI modules.

`ManifestLoader` decodes and encodes `ModelManifest` values from files, `ManifestStore`, and remote URLs using ISO 8601 dates,
keeping manifest loading in the lifecycle layer instead of pushing it into backends or UI. It can optionally
verify an expected manifest signature before decoding remote or persisted catalog data. `ModelManifestSignature`
supports SHA-256 digest checks for local compatibility and Ed25519 signatures for internet-loaded catalogs.

`DynamicModelCatalog` loads a remote manifest only when an Ed25519 signature validates, requires checksums on
downloadable remote artifacts, caches the accepted manifest, and falls back to a caller-provided catalog when
fetching or verification fails.

`ModelArtifactDownloading` is the injectable download boundary used by `ModelInstallCoordinator`. The default
`URLSessionModelArtifactDownloader` downloads declared `ModelArtifact` values to the configured artifact root directory.

`ModelIntegrityVerifier` validates manifest signatures plus downloaded artifact size and checksum metadata.
`ModelInstallCoordinator` now transitions installs through download and verification phases before marking a
model ready, and it records `.failed(...)` install state when download or integrity checks fail.

`InstalledModelRecordStore` persists installed model records through the backend-neutral `ManifestStore` contract. `ModelInstallCoordinator.persisted(recordStore:)` restores both installed records and `state(for:)` answers from that store.
