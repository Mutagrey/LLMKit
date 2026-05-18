# LLMUIDownloads Public API

Public API includes download list, install progress presentation, and a lifecycle-backed downloads view model.

`ModelDownloadListView` renders model descriptors with install actions, rounded installed/downloadable sections, and status text
backed by `ModelDownloadsViewModel`.
`ModelDownloadCardView` renders a single downloadable model with richer metadata, install action, and a linear progress treatment that
can be embedded by host apps alongside their own model selection UI. When lifecycle progress includes byte totals, the card renders
precise transferred bytes; otherwise it falls back to explicitly approximate progress text instead of implying exact byte tracking.
Hosts can optionally provide a cancel action for in-flight installs and a cleanup action for failed, evicted, or partial
local artifacts.
`ModelCatalogCardView` renders a compact model catalog row/card for model pickers and example catalogs. Hosts provide generic status,
availability, selection, install, cancel, delete, and details actions; the view does not choose models, route requests, or touch storage.
`ModelInstallProgressView` renders install state as a compact line-style progress component suitable for lists and detail sections.

`ModelDownloadsViewModel.install(_:)` consumes model install events, tracks in-flight installs by model ID, records thrown install
errors as short presentation-safe messages, updates install state by model ID, and stores richer progress detail when the
lifecycle layer exposes it. Raw `NSError` payloads, resume data, and presigned download URLs are not surfaced to views.
`refresh()` loads installed records and reconciles tracked descriptor states through `ModelLifecycleService` when one is provided.
When the lifecycle service also conforms to `ModelLifecycleMaintenanceService`, the view model exposes installed storage totals
and delete/clear actions without owning file paths or persistence details. Storage totals include configured descriptors with
partial artifacts, so failed downloads can still expose cleanup affordances.
`ModelDownloadsViewModel.beginInstall(_:)` and `cancelInstall(_:)` let hosts drive install lifecycle from UI without
holding task handles in view code. Cancel waits for lifecycle cancellation handling before allowing another install for the
same model; under the default lifecycle policy, that handling may preserve hidden resume data so retry can continue the
interrupted transfer without exposing resume files to UI.
