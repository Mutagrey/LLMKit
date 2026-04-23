# LLMModelLifecycle Public API

Public API includes manifests, catalog, installer, installed record persistence, and install state machine support.

`ModelArtifactDownloading` is the injectable download boundary used by `ModelInstallCoordinator`. The default
`URLSessionModelArtifactDownloader` downloads declared `ModelArtifact` values to the configured artifact root directory.

`InstalledModelRecordStore` persists installed model records through the backend-neutral `ManifestStore` contract. `ModelInstallCoordinator.persisted(recordStore:)` restores both installed records and `state(for:)` answers from that store.
