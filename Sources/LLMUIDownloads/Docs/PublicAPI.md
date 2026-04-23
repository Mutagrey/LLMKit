# LLMUIDownloads Public API

Public API includes download list, install progress presentation, and a lifecycle-backed downloads view model.

`ModelDownloadListView` renders model descriptors with install actions, progress, and status text backed by `ModelDownloadsViewModel`.

`ModelDownloadsViewModel.install(_:)` consumes model install events, tracks in-flight installs by model ID, records thrown install errors for presentation, and updates install state by model ID. `refresh()` loads installed records through `ModelLifecycleService` when one is provided.
