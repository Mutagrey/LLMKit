# LLMUIDownloads Public API

Public API includes download list, install progress presentation, and a lifecycle-backed downloads view model.

`ModelDownloadListView` renders model descriptors with install actions, grouped installed/downloadable sections, and status text
backed by `ModelDownloadsViewModel`.
`ModelDownloadCardView` renders a single downloadable model with richer metadata, install action, and a linear progress treatment that
can be embedded by host apps alongside their own model selection UI. When a descriptor carries
`estimatedDownloadSizeBytes`, the progress treatment can also render approximate transferred bytes. Hosts can optionally
provide a cancel action for in-flight installs.
`ModelInstallProgressView` renders install state as a compact line-style progress component suitable for lists and detail sections.

`ModelDownloadsViewModel.install(_:)` consumes model install events, tracks in-flight installs by model ID, records thrown install
errors for presentation, and updates install state by model ID. `refresh()` loads installed records and reconciles tracked descriptor
states through `ModelLifecycleService` when one is provided.
When the lifecycle service also conforms to `ModelLifecycleMaintenanceService`, the view model exposes installed storage totals
and delete actions without owning file paths or persistence details.
`ModelDownloadsViewModel.beginInstall(_:)` and `cancelInstall(_:)` let hosts drive install lifecycle from UI without
holding task handles in view code.
