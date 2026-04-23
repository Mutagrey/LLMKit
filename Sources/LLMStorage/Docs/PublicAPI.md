# LLMStorage Public API

Public API includes storage path and file-store primitives.

`ManifestFileStore` saves and loads manifest data by name, returning `nil` for missing manifests. `AtomicWriteCoordinator` creates parent directories and writes replacement data atomically.
