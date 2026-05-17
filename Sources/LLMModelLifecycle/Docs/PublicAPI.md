# LLMModelLifecycle Public API

Public API includes manifests, catalog, installer, installed record persistence, and install state machine support.

`CuratedModelManifests` exposes lifecycle-owned `ModelManifest` values for Apple system models and iPhone-oriented local MLX text
models, including Gemma 4 E2B Instruct 4-bit, so host apps can build catalogs without hardcoding descriptors in UI modules.

`ManifestLoader` decodes and encodes `ModelManifest` values from files, `ManifestStore`, and remote URLs using ISO 8601 dates,
keeping manifest loading in the lifecycle layer instead of pushing it into backends or UI. It can optionally
verify an expected manifest signature before decoding remote or persisted catalog data. `ModelManifestSignature`
supports SHA-256 digest checks for local compatibility and Ed25519 signatures for internet-loaded catalogs.

`DynamicModelCatalog` loads a remote manifest only when an Ed25519 signature validates, requires checksums on
downloadable remote artifacts, caches the accepted manifest, and falls back to a caller-provided catalog when
fetching or verification fails. It also exposes `ModelCatalogStatusProviding` so host UI can explain when the signed
remote manifest is active versus when a fallback catalog is being used.
`RemoteManifestTrustPolicy` lets hosts restrict internet-loaded catalogs to HTTPS, an explicit host allowlist, and
one or more trusted Ed25519 public keys so key rotation can happen without moving trust decisions into UI code.

`HuggingFaceFeaturedModelCatalog` is a lifecycle-owned live internet catalog for demo/example hosts. It resolves a curated
set of featured MLX repositories through Hugging Face model metadata, builds artifact lists from the live repository file
set, merges those descriptors with a local fallback catalog, and reports fallback status when the remote fetch fails.
The featured catalog includes the Gemma 4 E2B Instruct 4-bit MLX repository and preserves required tokenizer, safetensors,
chat template, and processor configuration artifacts when they are present.

`CompositeModelCatalog` combines multiple backend-neutral catalogs into one sorted model list, with later catalogs
replacing descriptors that share the same `ModelID`.

`ModelArtifactDownloading` is the injectable download boundary used by `ModelInstallCoordinator`. When an implementation
also conforms to `ProgressReportingModelArtifactDownloading`, the coordinator emits byte-level progress updates instead
of only per-file completion updates. The default `URLSessionModelArtifactDownloader` supports that richer progress path.
When only artifact-count progress is available, progress details omit byte totals so UI does not present file counts as bytes.
The default downloader retries transient URL loading failures with `URLSession` resume data when available, stores resume data
beside the destination artifact while retrying, preserves partial/resume artifacts after ordinary download failure for retry,
removes that cache after success or cancellation, coalesces high-frequency transfer callbacks before publishing lifecycle progress,
and maps transport failures
to short lifecycle errors without exposing presigned URLs or raw `NSError` payloads.
Task cancellation now propagates into the default downloader so user-requested cancellation can stop an in-flight transfer
instead of waiting for the current artifact to finish. Downloaders that own sidecar partial state can conform to
`ModelArtifactDownloadCacheCleaning` so cancellation cleanup can remove incomplete cache without touching verified artifacts.

`ModelIntegrityVerifier` validates manifest signatures plus downloaded artifact size and checksum metadata. Artifact checksums are
streamed from disk instead of loading full model files into memory.
`ModelInstallCoordinator` now transitions installs through download and verification phases before marking a
model ready, and it records `.failed(...)` install state when download or integrity checks fail.
Before downloading, it checks available disk space through `ModelInstallDiskSpaceProviding` when the manifest has known or
estimated download bytes, subtracting already verified artifacts so retries do not overstate required space.
`ModelInstallInterruptionPolicy` defines how cancellation cleanup behaves. The default policy preserves already verified
artifacts so a later install can resume from completed files while still deleting invalid leftovers from an interrupted
attempt. Callers that prefer the previous eager cleanup behavior can opt into `.removeAllArtifacts`.
When an install is cancelled, the coordinator still returns the install state to `.notInstalled` rather than leaving a
misleading terminal failure state behind.
Before downloading each declared artifact, the coordinator now checks whether a matching file is already present on disk
and reuses it when size and checksum validation pass, so repeated installs after restart can resume from completed files
instead of always downloading the full manifest again.

`InstalledModelRecordStore` persists installed model records through the backend-neutral `ManifestStore` contract. `ModelInstallCoordinator.persisted(recordStore:)` restores both installed records and `state(for:)` answers from that store.
`ModelInstallCoordinator` also conforms to `ModelLifecycleMaintenanceService` for user-requested deletion and storage usage
summaries. When initialized with a `recordStore`, it lazily restores records before answering state, install, delete, or storage
queries so app startup does not require async container construction.
