# LLMModelLifecycle Public API

Public API includes manifests, catalog, installer, installed record persistence, and install state machine skeletons.

`InstalledModelRecordStore` persists installed model records through the backend-neutral `ManifestStore` contract. `ModelInstallCoordinator.persisted(recordStore:)` restores coordinator state from that store.
