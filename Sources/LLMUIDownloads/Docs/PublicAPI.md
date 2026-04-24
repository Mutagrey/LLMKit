# LLMUIDownloads Public API

Public API includes download list, install progress presentation, and a lifecycle-backed downloads view model.

`ModelDownloadListView` renders model descriptors with install actions, grouped installed/downloadable sections, and status text
backed by `ModelDownloadsViewModel`.
`ModelDownloadCardView` renders a single downloadable model with richer metadata, install action, and a linear progress treatment that
can be embedded by host apps alongside their own model selection UI.
`ModelInstallProgressView` renders install state as a compact line-style progress component suitable for lists and detail sections.

`ModelDownloadsViewModel.install(_:)` consumes model install events, tracks in-flight installs by model ID, records thrown install
errors for presentation, and updates install state by model ID. `refresh()` loads installed records through `ModelLifecycleService`
when one is provided.
